import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart'; // LA VRAIE CARTE !
import 'package:latlong2/latlong.dart';        // COORDONNÉES GPS
import '../../models/user_model.dart';
import 'edit_patient_profile_screen.dart';

class BraceletStatusScreen extends StatefulWidget {
  final UserModel user;

  const BraceletStatusScreen({super.key, required this.user});

  @override
  State<BraceletStatusScreen> createState() => _BraceletStatusScreenState();
}

class _BraceletStatusScreenState extends State<BraceletStatusScreen> {
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryColor = Color(0xFF1565C0); // Bleu Médical
  static const Color dangerColor = Color(0xFFA32D2D);  // Rouge pro
  static const Color warningColor = Color(0xFFE65100);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🌟 POPUP DOSSIER MÉDICAL + VRAIE CARTE FLUTTER_MAP
  void _showPatientDetails(BuildContext context, Map<String, dynamic> patient) {
    final location = patient['location'] as Map<String, dynamic>? ?? {};
    final isConnected = patient['isConnected'] == true;
    final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
    final cinDisplay = patient['cin'] ?? 'Non renseignée';
    final batteryLevel = (patient['batteryLevel'] as int?) ?? 0;

    // Récupération des coordonnées GPS
    final city = location['city'] ?? 'Inconnue';
    double lat = 0.0;
    double lon = 0.0;

    // Parsing sécurisé des coordonnées
    if (location['lat'] != null) lat = double.tryParse(location['lat'].toString()) ?? 0.0;
    if (location['lon'] != null) lon = double.tryParse(location['lon'].toString()) ?? 0.0;

    final latLng = LatLng(lat, lon);
    final hasValidCoordinates = (lat != 0.0 && lon != 0.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.90, // Un peu plus grand pour la carte
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isConnected ? Icons.monitor_heart : Icons.portable_wifi_off, color: isConnected ? Colors.green : Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient['patientName'] ?? 'Sujet inconnu', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('CIN : $cinDisplay', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: primaryColor, size: 28),
                  tooltip: 'Modifier le dossier',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditPatientProfileScreen(bracelet: patient)));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // 🌟 LA VRAIE CARTE FLUTTER_MAP
                    Row(
                      children: [
                        const Icon(Icons.map, color: warningColor, size: 20),
                        const SizedBox(width: 8),
                        const Text('Dernière Position Connue', style: TextStyle(fontWeight: FontWeight.bold, color: warningColor, fontSize: 15)),
                        const Spacer(),
                        Text(city, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (hasValidCoordinates)
                      Container(
                        height: 200, // Hauteur de la vraie carte
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: latLng,
                              initialZoom: 14.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.falldetection.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: latLng,
                                    width: 60,
                                    height: 60,
                                    child: const Icon(Icons.location_on, color: dangerColor, size: 45),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[300]!)),
                        child: Column(
                          children: [
                            Icon(Icons.location_off, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Coordonnées GPS non disponibles', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // SECTION 2 : CONSTANTES
                    Row(
                      children: [
                        Expanded(child: _infoBox(Icons.cake, 'Âge', '${medical['age'] ?? 'N/A'} ans', primaryColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _infoBox(Icons.bloodtype, 'Groupe', '${medical['bloodType'] ?? 'N/A'}', dangerColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _infoBox(Icons.battery_charging_full, 'Batterie', '$batteryLevel%', batteryLevel < 20 ? dangerColor : Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // SECTION 3 : ANTÉCÉDENTS ET TRAITEMENTS
                    Row(
                      children: [
                        Icon(Icons.history_edu, color: Colors.blue[800], size: 20),
                        const SizedBox(width: 8),
                        Text('Antécédents médicaux', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                      child: Text(medical['conditions']?.isNotEmpty == true ? medical['conditions'] : 'Aucun antécédent majeur déclaré.', style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Icon(Icons.medication, color: Colors.purple[800], size: 20),
                        const SizedBox(width: 8),
                        Text('Traitements en cours', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[800])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(10)),
                      child: Text(medical['medications']?.isNotEmpty == true ? medical['medications'] : 'Aucun traitement en cours.', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Parc Bracelets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un patient (Nom ou CIN)...',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: widget.user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryColor));

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucun patient', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('Vous n\'avez aucun patient à charge.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final bracelets = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '').toString().toLowerCase();
                  final cin = (data['cin'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || cin.contains(searchQuery);
                }).toList();

                if (bracelets.isEmpty) {
                  return const Center(child: Text('Aucun patient trouvé.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bracelets.length,
                  itemBuilder: (context, index) {
                    final b = bracelets[index].data() as Map<String, dynamic>;
                    final isConnected = b['isConnected'] == true;
                    final cinDisplay = b['cin'] ?? 'Non renseignée';
                    final batteryLevel = (b['batteryLevel'] as int?) ?? 0;
                    final city = b['location']?['city'] ?? 'Localisation inconnue';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showPatientDetails(context, b),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(color: isConnected ? const Color(0xFFEDF7ED) : const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(14)),
                                    child: Icon(isConnected ? Icons.monitor_heart : Icons.portable_wifi_off, color: isConnected ? Colors.green : Colors.red, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b['patientName'] ?? 'Patient inconnu', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('CIN: $cinDisplay', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: isConnected ? const Color(0xFFEDF7ED) : const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isConnected ? Icons.wifi : Icons.wifi_off, size: 10, color: isConnected ? Colors.green : Colors.red),
                                                  const SizedBox(width: 4),
                                                  Text(isConnected ? 'En ligne' : 'Hors-ligne', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isConnected ? Colors.green : Colors.red)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(color: batteryLevel < 20 ? const Color(0xFFFCEBEB) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(batteryLevel < 20 ? Icons.battery_alert : Icons.battery_charging_full, size: 10, color: batteryLevel < 20 ? Colors.red : Colors.green),
                                                  const SizedBox(width: 4),
                                                  Text('$batteryLevel%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: batteryLevel < 20 ? Colors.red : Colors.green)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                            const Divider(height: 0.5, thickness: 0.5),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: warningColor),
                                  const SizedBox(width: 6),
                                  Text(city, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  const Text('Dossier Complet', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
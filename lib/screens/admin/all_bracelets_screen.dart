import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllBraceletsScreen extends StatefulWidget {
  const AllBraceletsScreen({super.key});

  @override
  State<AllBraceletsScreen> createState() => _AllBraceletsScreenState();
}

class _AllBraceletsScreenState extends State<AllBraceletsScreen> {
  String searchQuery = ''; // Barre de recherche

  // 🌟 POPUP DOSSIER MÉDICAL (DESIGN PRO)
  void _showMedicalRecord(BuildContext context, Map<String, dynamic> b) {
    final medical = b['medicalRecord'] ?? {};
    final isConnected = b['isConnected'] == true;
    final cinDisplay = b['cin'] ?? 'Non renseignée';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête de la popup
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFFEDF7ED) : const Color(0xFFFCEBEB),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isConnected ? Icons.monitor_heart : Icons.portable_wifi_off,
                        color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFA32D2D),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dossier Patient',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFA32D2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b['patientName'] ?? 'Inconnu',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ],
                  ),
                ),

                // Corps du dossier
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.badge, 'Numéro CIN :', cinDisplay),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.medical_services, 'Soignant :', 'Dr. ${b['ownerName'] ?? 'Non assigné'}'),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.cake, 'Âge :', '${medical['age'] ?? 'N/A'} ans'),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.bloodtype, 'Groupe Sanguin :', '${medical['bloodType'] ?? 'N/A'}'),

                      const SizedBox(height: 20),

                      // Section Antécédents
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

                      // Section Traitements
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer le dossier', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Tous les Patients', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B), // Vert médical foncé
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🌟 BARRE DE RECHERCHE INTELLIGENTE
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher (Nom, CIN, ou Soignant)...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00796B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aucun patient enregistré.'));

                // 🌟 FILTRAGE DES RÉSULTATS
                final bracelets = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '').toString().toLowerCase();
                  final cin = (data['cin'] ?? '').toString().toLowerCase();
                  final owner = (data['ownerName'] ?? '').toString().toLowerCase();

                  return name.contains(searchQuery) || cin.contains(searchQuery) || owner.contains(searchQuery);
                }).toList();

                if (bracelets.isEmpty) {
                  return const Center(child: Text('Aucun patient ne correspond à cette recherche.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bracelets.length,
                  itemBuilder: (context, index) {
                    final b = bracelets[index].data() as Map<String, dynamic>;
                    final braceletId = bracelets[index].id;
                    final isConnected = b['isConnected'] == true;
                    final cinDisplay = b['cin'] ?? 'Non renseignée';

                    // 🌟 CARTE PATIENT PROFESSIONNELLE
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showMedicalRecord(context, b),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              child: Row(
                                children: [
                                  // Avatar Statut Capteur
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isConnected ? const Color(0xFFEDF7ED) : const Color(0xFFFCEBEB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      isConnected ? Icons.monitor_heart : Icons.portable_wifi_off,
                                      color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFA32D2D),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Infos Patient
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b['patientName'] ?? 'Patient inconnu',
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text('CIN: $cinDisplay', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 6),

                                        // Badge statut de connexion
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isConnected ? const Color(0xFFEDF7ED) : const Color(0xFFFCEBEB),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isConnected ? Icons.wifi : Icons.wifi_off,
                                                size: 12,
                                                color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFA32D2D),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isConnected ? 'Capteur Actif' : 'Capteur Déconnecté',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isConnected ? const Color(0xFF2E7D32) : const Color(0xFFA32D2D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Bouton Corbeille
                                  GestureDetector(
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Retirer le capteur ?', style: TextStyle(color: Colors.red)),
                                          content: Text('Voulez-vous vraiment retirer le capteur de ${b['patientName']} du système ?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Supprimer'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).delete();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFA32D2D)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(height: 0.5, thickness: 0.5),

                            // Pied de carte : Soignant affecté
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.medical_services_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Suivi par : ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  Text(
                                    'Dr. ${b['ownerName'] ?? 'Non assigné'}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
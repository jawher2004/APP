import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllAlertsScreen extends StatefulWidget {
  const AllAlertsScreen({super.key});

  @override
  State<AllAlertsScreen> createState() => _AllAlertsScreenState();
}

class _AllAlertsScreenState extends State<AllAlertsScreen> {
  String searchQuery = '';

  DateTime? _parseTimestamp(dynamic rawTime) {
    if (rawTime == null) return null;
    if (rawTime is Timestamp) return rawTime.toDate();
    if (rawTime is int) {
      if (rawTime.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(rawTime * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(rawTime);
    }
    if (rawTime is String) return DateTime.tryParse(rawTime);
    return null;
  }

  // 🌟 LE RAPPORT MÉDICAL IA (ULTRA-PRO)
  void _showAlertDetails(BuildContext context, Map<String, dynamic> alertData, String cin, String dateFullStr) {
    // 1. Détection du type d'anomalie
    final type = alertData['type'] ?? 'INCONNU';
    final isFalseAlarm = alertData['isFalseAlarm'] == true;
    final conf = (alertData['probability'] ?? 0) * 100;

    // 2. Lecture des données météo/localisation depuis ton champ 'weather' !
    String location = 'Inconnue';
    String temp = '';
    if (alertData['weather'] is Map) {
      final weather = alertData['weather'];
      location = weather['city'] ?? 'Ville inconnue';
      if (weather['temperature'] != null) {
        temp = ' (${weather['temperature']}°C)';
      }
    }

    // 3. Lecture du rapport IA de ton backend
    final aiReport = alertData['aiReport'] ?? 'Aucune analyse IA disponible pour cet événement.';
    final source = alertData['source'] ?? 'Capteur';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        // On rend la popup "scrollable" au cas où le rapport IA est très long
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // — En-tête de la popup (Rouge ou Gris selon l'alerte)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isFalseAlarm ? const Color(0xFFF1EFE8) : const Color(0xFFFCEBEB),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isFalseAlarm ? Icons.insights_rounded : Icons.personal_injury,
                        color: isFalseAlarm ? const Color(0xFF5F5E5A) : const Color(0xFFA32D2D),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFalseAlarm ? 'Écart Cinématique Mineur' : 'Rapport d\'Urgence Médicale',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isFalseAlarm ? const Color(0xFF444441) : const Color(0xFFA32D2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Détecté par : $source',
                        style: TextStyle(
                          fontSize: 12,
                          color: isFalseAlarm ? const Color(0xFF5F5E5A) : const Color(0xFFA32D2D),
                        ),
                      )
                    ],
                  ),
                ),

                // — Corps du rapport (Informations basiques)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.person, 'Sujet :', alertData['patientName'] ?? 'Sujet inconnu'),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.badge, 'Numéro CIN :', cin),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.access_time, 'Horodatage :', dateFullStr),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.location_on, 'Localisation :', '$location$temp'),
                      const Divider(height: 12, thickness: 0.5),
                      _buildDetailRow(Icons.analytics_outlined, 'Certitude de l\'anomalie :', '${conf.toInt()}%'),

                      const SizedBox(height: 24),

                      // 🌟 AFFICHAGE DU RAPPORT IA (La pièce maîtresse !)
                      Row(
                        children: [
                          const Icon(Icons.psychology, color: Colors.deepPurple, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Analyse Prédictive IA',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.deepPurple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                        ),
                        child: Text(
                          aiReport,
                          style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                        ),
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
            child: const Text('Fermer', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Widget utilitaire pour les lignes
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // Petit widget pour afficher les lignes de la popup proprement

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Registre Cinématique', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher par CIN ou Date (ex: 13/05/2026)...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFD32F2F)),
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
              builder: (context, braceletsSnapshot) {
                if (braceletsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                }

                Map<String, String> cinDictionary = {};
                if (braceletsSnapshot.hasData) {
                  for (var doc in braceletsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cin = data['cin']?.toString() ?? 'Non renseignée';
                    cinDictionary[doc.id] = cin;
                    if (data['braceletId'] != null) cinDictionary[data['braceletId']] = cin;
                    if (data['patientName'] != null) cinDictionary[data['patientName']] = cin;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('alerts').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, alertsSnapshot) {
                    if (alertsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                    }
                    if (!alertsSnapshot.hasData || alertsSnapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    var alerts = alertsSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final alertBraceletId = data['braceletId']?.toString() ?? '';
                      final alertPatientName = data['patientName']?.toString() ?? '';
                      final resolvedCin = cinDictionary[alertBraceletId] ?? cinDictionary[alertPatientName] ?? data['cin']?.toString() ?? 'Non renseignée';
                      final DateTime? alertDate = _parseTimestamp(data['timestamp']);
                      final dateOnlyStr = alertDate != null ? DateFormat('dd/MM/yyyy').format(alertDate) : '';

                      return resolvedCin.toLowerCase().contains(searchQuery) || dateOnlyStr.contains(searchQuery);
                    }).toList();

                    if (alerts.isEmpty) return _buildEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alertData = alerts[index].data() as Map<String, dynamic>;
                        final alertId = alerts[index].id;

                        final isFalseAlarm = alertData['isFalseAlarm'] == true;
                        final conf = (alertData['probability'] ?? 0) * 100;

                        final DateTime? alertDate = _parseTimestamp(alertData['timestamp']);
                        final dateFullStr = alertDate != null ? DateFormat('dd/MM/yyyy à HH:mm').format(alertDate) : 'Date inconnue';

                        final alertBraceletId = alertData['braceletId']?.toString() ?? '';
                        final alertPatientName = alertData['patientName']?.toString() ?? '';
                        final cinDisplay = cinDictionary[alertBraceletId] ?? cinDictionary[alertPatientName] ?? alertData['cin']?.toString() ?? 'Non renseignée';

                        // 🌟 GESTURE DETECTOR AUTOUR DE LA CARTE POUR L'OUVRIR
                        return GestureDetector(
                          onTap: () => _showAlertDetails(context, alertData, cinDisplay, dateFullStr),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: Colors.white,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isFalseAlarm ? const Color(0xFFF1EFE8) : const Color(0xFFFCEBEB),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isFalseAlarm ? Icons.insights_rounded : Icons.personal_injury,
                                          color: isFalseAlarm ? const Color(0xFF5F5E5A) : const Color(0xFFA32D2D),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alertData['patientName'] ?? 'Sujet inconnu',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text('CIN: $cinDisplay', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isFalseAlarm ? const Color(0xFFF1EFE8) : const Color(0xFFFCEBEB),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isFalseAlarm ? Icons.filter_center_focus : Icons.warning_rounded,
                                                    size: 12,
                                                    color: isFalseAlarm ? const Color(0xFF444441) : const Color(0xFFA32D2D),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isFalseAlarm ? 'Écart mineur ignoré' : 'Anomalie de mouvement',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isFalseAlarm ? const Color(0xFF444441) : const Color(0xFFA32D2D),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                        child: Column(
                                          children: [
                                            const Text('Score IA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                                            Text('${conf.toInt()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey[800])),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                const Divider(height: 0.5, thickness: 0.5),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(dateFullStr, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      // Bouton qui invite au clic
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('Voir détails', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_heart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Aucun résultat trouvé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Aucune anomalie correspondant à cette recherche.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
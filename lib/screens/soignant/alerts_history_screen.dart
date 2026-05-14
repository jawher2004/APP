import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/alert_model.dart';
import 'alert_details_screen.dart';

class AlertsHistoryScreen extends StatefulWidget {
  final UserModel user;

  const AlertsHistoryScreen({super.key, required this.user});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  String searchQuery = '';

  static const Color primaryColor = Color(0xFF1565C0); // Bleu Médical
  static const Color dangerColor = Color(0xFFA32D2D);  // Rouge pro

  void _showAlertDetails(AlertModel alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertDetailsScreen(alert: alert),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fond très clair clinique
      appBar: AppBar(
        title: const Text('Registre Cinématique', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // BARRE DE RECHERCHE
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Rechercher par Nom, CIN ou Date...',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // 🌟 ETAPE 1: CHARGEMENT DES PATIENTS DU MÉDECIN POUR RÉCUPÉRER LES CIN
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: widget.user.uid).snapshots(),
              builder: (context, braceletsSnapshot) {
                if (braceletsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }

                // Création du dictionnaire intelligent
                Map<String, String> cinDictionary = {};
                if (braceletsSnapshot.hasData) {
                  for (var doc in braceletsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cin = data['cin']?.toString() ?? 'Non renseignée';
                    cinDictionary[doc.id] = cin;
                    if (data['braceletId'] != null) cinDictionary[data['braceletId']] = cin;
                  }
                }

                // 🌟 ETAPE 2: CHARGEMENT DES ALERTES DU MÉDECIN
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('alerts')
                      .where('ownerId', isEqualTo: widget.user.uid)
                      .snapshots(),
                  builder: (context, alertsSnapshot) {
                    if (alertsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: primaryColor));
                    }

                    if (alertsSnapshot.hasError) {
                      return Center(child: Text('Erreur: ${alertsSnapshot.error}'));
                    }

                    if (!alertsSnapshot.hasData || alertsSnapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    // 1. Transformation en AlertModel
                    var alertsList = alertsSnapshot.data!.docs
                        .map((doc) => AlertModel.fromFirestore(doc))
                        .toList();

                    // 2. Tri Manuel (Le plus récent en premier)
                    alertsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    // 3. Filtrage avec la barre de recherche (Nom, Date OU CIN)
                    var filteredAlerts = alertsList.where((alert) {
                      final patientName = alert.patientName.toLowerCase();
                      final dateStr = DateFormat('dd/MM/yyyy').format(alert.createdAt);

                      // On récupère la CIN depuis le dictionnaire
                      final cin = cinDictionary[alert.braceletId] ?? 'Non renseignée';
                      final cinSearch = cin.toLowerCase();

                      return patientName.contains(searchQuery) || dateStr.contains(searchQuery) || cinSearch.contains(searchQuery);
                    }).toList();

                    if (filteredAlerts.isEmpty) return _buildEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = filteredAlerts[index];
                        final isFalseAlarm = alert.type != 'FALL';
                        final dateFullStr = DateFormat('dd/MM/yyyy à HH:mm').format(alert.createdAt);

                        // Récupération de la CIN pour l'affichage
                        final cinDisplay = cinDictionary[alert.braceletId] ?? 'Non renseignée';

                        return GestureDetector(
                          onTap: () => _showAlertDetails(alert),
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
                                        decoration: BoxDecoration(color: isFalseAlarm ? const Color(0xFFF1EFE8) : const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(14)),
                                        child: Icon(isFalseAlarm ? Icons.insights_rounded : Icons.personal_injury, color: isFalseAlarm ? const Color(0xFF5F5E5A) : dangerColor, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(alert.patientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            // 🌟 AFFICHAGE DE LA CIN ICI
                                            Text('CIN: $cinDisplay', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(color: isFalseAlarm ? const Color(0xFFF1EFE8) : const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isFalseAlarm ? Icons.filter_center_focus : Icons.warning_rounded, size: 12, color: isFalseAlarm ? const Color(0xFF444441) : dangerColor),
                                                  const SizedBox(width: 4),
                                                  Text(isFalseAlarm ? 'Écart mineur ignoré' : 'Anomalie de mouvement', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isFalseAlarm ? const Color(0xFF444441) : dangerColor)),
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
                                            Text(alert.probabilityPercent, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey[800])),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('Ouvrir le dossier', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
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
          const Text('Registre vierge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Aucune anomalie enregistrée pour vos patients.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
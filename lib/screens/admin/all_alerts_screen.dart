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

    if (rawTime is Timestamp) {
      return rawTime.toDate();
    }

    if (rawTime is int) {
      if (rawTime.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(rawTime * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(rawTime);
    }

    if (rawTime is String) {
      return DateTime.tryParse(rawTime);
    }

    return null;
  }

  void _showAlertDetails(
      BuildContext context,
      Map<String, dynamic> alertData,
      String patientCin,
      String caregiverCin,
      String caregiverName,
      String dateFullStr,
      ) {
    final isFalseAlarm = alertData['isFalseAlarm'] == true;
    final conf = (alertData['probability'] ?? 0) * 100;

    String location = 'Inconnue';
    String temp = '';

    if (alertData['weather'] is Map) {
      final weather = alertData['weather'];
      location = weather['city'] ?? 'Ville inconnue';

      if (weather['temperature'] != null) {
        temp = ' (${weather['temperature']}°C)';
      }
    }

    final aiReport =
        alertData['aiReport'] ?? 'Aucune analyse IA disponible pour cet événement.';
    final source = alertData['source'] ?? 'Capteur';

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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isFalseAlarm
                        ? const Color(0xFFF1EFE8)
                        : const Color(0xFFFCEBEB),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isFalseAlarm
                            ? Icons.insights_rounded
                            : Icons.personal_injury,
                        color: isFalseAlarm
                            ? const Color(0xFF5F5E5A)
                            : const Color(0xFFA32D2D),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFalseAlarm
                            ? 'Écart Cinématique Mineur'
                            : 'Rapport d\'Urgence Médicale',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isFalseAlarm
                              ? const Color(0xFF444441)
                              : const Color(0xFFA32D2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Détecté par : $source',
                        style: TextStyle(
                          fontSize: 12,
                          color: isFalseAlarm
                              ? const Color(0xFF5F5E5A)
                              : const Color(0xFFA32D2D),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.person,
                        'Sujet :',
                        alertData['patientName'] ?? 'Sujet inconnu',
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.badge,
                        'CIN patient :',
                        patientCin,
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.medical_services_outlined,
                        'Soignant :',
                        caregiverName,
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.credit_card_outlined,
                        'CIN soignant :',
                        caregiverCin,
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.access_time,
                        'Horodatage :',
                        dateFullStr,
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.location_on,
                        'Localisation :',
                        '$location$temp',
                      ),
                      const Divider(height: 12, thickness: 0.5),

                      _buildDetailRow(
                        Icons.analytics_outlined,
                        'Probabilité de chute :',
                        '${conf.toInt()}%',
                      ),

                      const SizedBox(height: 24),

                      const Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Analyse Prédictive IA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.deepPurple,
                            ),
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
                          border: Border.all(
                            color: Colors.deepPurple.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          aiReport,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.black87,
                          ),
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
            child: const Text(
              'Fermer',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveValueFromDictionaries({
    required Map<String, String> dictionary,
    required String braceletId,
    required String patientName,
    required String fallback,
  }) {
    return dictionary[braceletId] ??
        dictionary[patientName] ??
        fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          'Registre',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() => searchQuery = value.toLowerCase());
              },
              decoration: InputDecoration(
                hintText: 'Rechercher par CIN, CIN soignant ou Date...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFFD32F2F),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bracelets')
                  .snapshots(),
              builder: (context, braceletsSnapshot) {
                if (braceletsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD32F2F),
                    ),
                  );
                }

                Map<String, String> patientCinDictionary = {};
                Map<String, String> ownerIdDictionary = {};
                Map<String, String> ownerNameDictionary = {};

                if (braceletsSnapshot.hasData) {
                  for (var doc in braceletsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    final patientCin =
                        data['cin']?.toString() ?? 'Non renseignée';
                    final ownerId = data['ownerId']?.toString() ?? '';
                    final ownerName =
                        data['ownerName']?.toString() ?? 'Aucun soignant';

                    patientCinDictionary[doc.id] = patientCin;
                    ownerIdDictionary[doc.id] = ownerId;
                    ownerNameDictionary[doc.id] = ownerName;

                    if (data['braceletId'] != null) {
                      final braceletId = data['braceletId'].toString();
                      patientCinDictionary[braceletId] = patientCin;
                      ownerIdDictionary[braceletId] = ownerId;
                      ownerNameDictionary[braceletId] = ownerName;
                    }

                    if (data['patientName'] != null) {
                      final patientName = data['patientName'].toString();
                      patientCinDictionary[patientName] = patientCin;
                      ownerIdDictionary[patientName] = ownerId;
                      ownerNameDictionary[patientName] = ownerName;
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'soignant')
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    Map<String, String> caregiverCinDictionary = {};
                    Map<String, String> caregiverNameDictionary = {};

                    if (usersSnapshot.hasData) {
                      for (var doc in usersSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;

                        caregiverCinDictionary[doc.id] =
                            data['cin']?.toString() ?? 'Non renseignée';

                        caregiverNameDictionary[doc.id] =
                            data['name']?.toString() ?? 'Soignant inconnu';
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('alerts')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, alertsSnapshot) {
                        if (alertsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD32F2F),
                            ),
                          );
                        }

                        if (!alertsSnapshot.hasData ||
                            alertsSnapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final alerts =
                        alertsSnapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          final alertBraceletId =
                              data['braceletId']?.toString() ?? '';
                          final alertPatientName =
                              data['patientName']?.toString() ?? '';

                          final patientCin = _resolveValueFromDictionaries(
                            dictionary: patientCinDictionary,
                            braceletId: alertBraceletId,
                            patientName: alertPatientName,
                            fallback: data['cin']?.toString() ??
                                'Non renseignée',
                          );

                          final ownerIdFromAlert =
                              data['ownerId']?.toString() ?? '';

                          final resolvedOwnerId =
                          ownerIdFromAlert.isNotEmpty
                              ? ownerIdFromAlert
                              : _resolveValueFromDictionaries(
                            dictionary: ownerIdDictionary,
                            braceletId: alertBraceletId,
                            patientName: alertPatientName,
                            fallback: '',
                          );

                          final caregiverCin =
                              caregiverCinDictionary[resolvedOwnerId] ??
                                  'Non renseignée';

                          final DateTime? alertDate =
                          _parseTimestamp(data['timestamp']);

                          final dateOnlyStr = alertDate != null
                              ? DateFormat('dd/MM/yyyy').format(alertDate)
                              : '';

                          return patientCin
                              .toLowerCase()
                              .contains(searchQuery) ||
                              caregiverCin
                                  .toLowerCase()
                                  .contains(searchQuery) ||
                              dateOnlyStr.contains(searchQuery);
                        }).toList();

                        if (alerts.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: alerts.length,
                          itemBuilder: (context, index) {
                            final alertData =
                            alerts[index].data() as Map<String, dynamic>;

                            final isFalseAlarm =
                                alertData['isFalseAlarm'] == true;
                            final conf =
                                (alertData['probability'] ?? 0) * 100;

                            final DateTime? alertDate =
                            _parseTimestamp(alertData['timestamp']);

                            final dateFullStr = alertDate != null
                                ? DateFormat('dd/MM/yyyy à HH:mm')
                                .format(alertDate)
                                : 'Date inconnue';

                            final alertBraceletId =
                                alertData['braceletId']?.toString() ?? '';
                            final alertPatientName =
                                alertData['patientName']?.toString() ?? '';

                            final patientCinDisplay =
                            _resolveValueFromDictionaries(
                              dictionary: patientCinDictionary,
                              braceletId: alertBraceletId,
                              patientName: alertPatientName,
                              fallback: alertData['cin']?.toString() ??
                                  'Non renseignée',
                            );

                            final ownerIdFromAlert =
                                alertData['ownerId']?.toString() ?? '';

                            final resolvedOwnerId =
                            ownerIdFromAlert.isNotEmpty
                                ? ownerIdFromAlert
                                : _resolveValueFromDictionaries(
                              dictionary: ownerIdDictionary,
                              braceletId: alertBraceletId,
                              patientName: alertPatientName,
                              fallback: '',
                            );

                            final caregiverCinDisplay =
                                caregiverCinDictionary[resolvedOwnerId] ??
                                    'Non renseignée';

                            final caregiverNameDisplay =
                                caregiverNameDictionary[resolvedOwnerId] ??
                                    _resolveValueFromDictionaries(
                                      dictionary: ownerNameDictionary,
                                      braceletId: alertBraceletId,
                                      patientName: alertPatientName,
                                      fallback: 'Aucun soignant',
                                    );

                            return GestureDetector(
                              onTap: () => _showAlertDetails(
                                context,
                                alertData,
                                patientCinDisplay,
                                caregiverCinDisplay,
                                caregiverNameDisplay,
                                dateFullStr,
                              ),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isFalseAlarm
                                                  ? const Color(0xFFF1EFE8)
                                                  : const Color(0xFFFCEBEB),
                                              borderRadius:
                                              BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              isFalseAlarm
                                                  ? Icons.insights_rounded
                                                  : Icons.personal_injury,
                                              color: isFalseAlarm
                                                  ? const Color(0xFF5F5E5A)
                                                  : const Color(0xFFA32D2D),
                                              size: 24,
                                            ),
                                          ),

                                          const SizedBox(width: 14),

                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  alertData['patientName'] ??
                                                      'Sujet inconnu',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                  ),
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),

                                                const SizedBox(height: 2),

                                                Text(
                                                  'CIN patient : $patientCinDisplay',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),

                                                const SizedBox(height: 2),

                                                Text(
                                                  'Soignant : $caregiverNameDisplay',
                                                  maxLines: 1,
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),

                                                const SizedBox(height: 2),

                                                Text(
                                                  'CIN soignant : $caregiverCinDisplay',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),

                                                const SizedBox(height: 6),

                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isFalseAlarm
                                                        ? const Color(
                                                        0xFFF1EFE8)
                                                        : const Color(
                                                        0xFFFCEBEB),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isFalseAlarm
                                                            ? Icons
                                                            .filter_center_focus
                                                            : Icons
                                                            .warning_rounded,
                                                        size: 12,
                                                        color: isFalseAlarm
                                                            ? const Color(
                                                            0xFF444441)
                                                            : const Color(
                                                            0xFFA32D2D),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        isFalseAlarm
                                                            ? 'Écart mineur ignoré'
                                                            : 'Perte d’équilibre détectée',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                          FontWeight.w600,
                                                          color: isFalseAlarm
                                                              ? const Color(
                                                              0xFF444441)
                                                              : const Color(
                                                              0xFFA32D2D),
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
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  'Score IA',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                Text(
                                                  '${conf.toInt()}%',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Divider(
                                      height: 0.5,
                                      thickness: 0.5,
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateFullStr,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          const Spacer(),

                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Voir détails',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
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
          Icon(
            Icons.monitor_heart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aucune anomalie correspondant à cette recherche.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
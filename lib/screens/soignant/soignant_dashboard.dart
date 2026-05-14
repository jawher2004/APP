import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'alerts_history_screen.dart';
import 'bracelet_status_screen.dart';
import 'profile_settings_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'patients_map_screen.dart';

class SoignantDashboard extends StatefulWidget {
  final UserModel user;

  const SoignantDashboard({super.key, required this.user});

  @override
  State<SoignantDashboard> createState() => _SoignantDashboardState();
}

class _SoignantDashboardState extends State<SoignantDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryColor = Color(0xFF00695C);
  static const Color secondaryColor = Color(0xFF26A69A);
  static const Color dangerColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color purpleColor = Color(0xFF5E35B1);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _callGemini(BuildContext context, String prompt) async {
    try {
      final response = await http
          .post(
        Uri.parse(
          'https://fall-detection-backend-7w0h.onrender.com/api/generate-report',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['report'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  DateTime? _extractAlertDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final timestamp = data['timestamp'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }

    if (timestamp is double) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    }

    return null;
  }

  bool _isLast24Hours(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    return difference.inHours <= 24 && !date.isAfter(now);
  }

  bool _isRealEmergency(Map<String, dynamic> data) {
    if (data['status']?.toString().toUpperCase() == 'FALSE_ALERT') {
      return false;
    }

    if (data['isFalseAlarm'] == true) {
      return false;
    }

    return data['type']?.toString().toUpperCase() == 'FALL';
  }

  String _formatDate(Map<String, dynamic> data) {
    final date = _extractAlertDate(data);
    if (date == null) return 'Date inconnue';
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  String _extractCity(Map<String, dynamic> data) {
    final weather = data['weather'];
    final location = data['location'];

    if (weather is Map && weather['city'] != null) {
      return weather['city'].toString();
    }

    if (location is Map && location['city'] != null) {
      return location['city'].toString();
    }

    return 'Localisation inconnue';
  }
  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is int) return value.toDouble();
    if (value is double) return value;

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  latlng.LatLng _calculateCenter(List<latlng.LatLng> points) {
    if (points.isEmpty) {
      return const latlng.LatLng(36.8065, 10.1815); // Tunis par défaut
    }

    double totalLat = 0;
    double totalLon = 0;

    for (final point in points) {
      totalLat += point.latitude;
      totalLon += point.longitude;
    }

    return latlng.LatLng(
      totalLat / points.length,
      totalLon / points.length,
    );
  }
  String _probabilityPercent(Map<String, dynamic> data) {
    final value = data['probability'];

    if (value is int) return '${(value * 100).round()}%';
    if (value is double) return '${(value * 100).round()}%';

    return 'N/A';
  }

  Color _getProbabilityColor(dynamic probability) {
    double value = 0;

    if (probability is int) value = probability.toDouble();
    if (probability is double) value = probability;

    if (value >= 0.8) return dangerColor;
    if (value >= 0.5) return warningColor;
    return Colors.amber[700]!;
  }

  Color _getBatteryColor(int level) {
    if (level <= 15) return dangerColor;
    if (level <= 30) return warningColor;
    return Colors.green;
  }

  IconData _getBatteryIcon(int level) {
    if (level <= 15) return Icons.battery_alert;
    if (level <= 30) return Icons.battery_2_bar;
    if (level <= 60) return Icons.battery_4_bar;
    return Icons.battery_full;
  }

  Future<void> _markAlertTreated(String alertId) async {
    await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
      'status': 'TREATED',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerte marquée comme traitée'),
          backgroundColor: primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _generateGlobalBilan(
      BuildContext context,
      Map<String, dynamic> patient,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 12),
            const Text(
              'Analyse en cours…',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Génération du bilan IA',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                color: purpleColor,
                backgroundColor: Color(0xFFEDE7F6),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final braceletId = patient['id'] ?? patient['braceletId'] ?? '';
      final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
      final location = patient['location'] as Map<String, dynamic>? ?? {};

      final alertsSnap = await FirebaseFirestore.instance
          .collection('alerts')
          .where('braceletId', isEqualTo: braceletId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final totalFalls = alertsSnap.docs.length;

      final falseAlerts = alertsSnap.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'FALSE_ALERT' || data['isFalseAlarm'] == true;
      }).length;

      final realFalls = totalFalls - falseAlerts;

      final fallsDetails = alertsSnap.docs.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final alert = entry.value.data();

        final weather = alert['weather'] != null
            ? "${alert['weather']['temperature']}°C, "
            "${alert['weather']['description']}, "
            "humidité ${alert['weather']['humidity']}%"
            : 'Non disponible';

        return "Événement $index — ${_formatDate(alert)}\n"
            "  · Météo: $weather\n"
            "  · Certitude IA: ${((alert['probability'] ?? 0) * 100).round()}%\n"
            "  · Statut: ${alert['status'] ?? 'NON_TRAITE'}";
      }).join('\n\n');

      final prompt =
          "Tu es un médecin gériatre expert en prévention des chutes.\n\n"
          "DOSSIER MÉDICAL :\n"
          "Nom: ${patient['patientName'] ?? 'Inconnu'}\n"
          "CIN: ${patient['cin'] ?? 'N/A'}\n"
          "Âge: ${medical['age'] ?? '?'} ans\n"
          "Groupe sanguin: ${medical['bloodType'] ?? 'N/A'}\n"
          "Pathologies: ${medical['conditions'] ?? 'Aucune'}\n"
          "Médicaments: ${medical['medications'] ?? 'Aucun'}\n"
          "Ville: ${location['city'] ?? 'Inconnue'}\n\n"
          "STATISTIQUES :\n"
          "Total: $totalFalls | Confirmées: $realFalls | Fausses: $falseAlerts\n\n"
          "HISTORIQUE :\n"
          "${fallsDetails.isNotEmpty ? fallsDetails : 'Aucune anomalie.'}\n\n"
          "Rédige un bilan en 4 parties : évaluation du risque, patterns, "
          "facteurs de risque, recommandations.";

      final bilan = await _callGemini(context, prompt);

      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;

      if (bilan != null) {
        await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).update({
          'lastBilan': bilan,
          'lastBilanDate': FieldValue.serverTimestamp(),
          'lastBilanFallsCount': totalFalls,
          'lastBilanGeneratedBy': widget.user.uid,
        });

        _showBilanDialog(
          context,
          patient['patientName'] ?? 'Patient',
          bilan,
          {
            'total': totalFalls,
            'real': realFalls,
            'falseAlerts': falseAlerts,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le serveur IA ne répond pas. Réessayez.'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: dangerColor,
        ),
      );
    }
  }

  Future<void> _checkAndShowBilan(
      BuildContext context,
      Map<String, dynamic> patient,
      ) async {
    final existingBilan = patient['lastBilan'] as String?;
    final existingBilanDate = patient['lastBilanDate'] as Timestamp?;

    if (existingBilan != null && existingBilan.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.summarize, color: purpleColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Bilan IA disponible',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existingBilanDate != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: purpleColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: purpleColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(existingBilanDate.toDate())}',
                          style: const TextStyle(fontSize: 11, color: purpleColor),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'Un bilan existe déjà. Afficher ou régénérer ?',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'afficher'),
              child: const Text('Afficher'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'regenerer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Régénérer'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (choice == 'afficher') {
        _showBilanDialog(
          context,
          patient['patientName'] ?? 'Patient',
          existingBilan,
          {
            'total': patient['lastBilanFallsCount'] ?? 0,
            'real': patient['lastBilanFallsCount'] ?? 0,
            'falseAlerts': 0,
          },
        );
        return;
      }
    }

    _generateGlobalBilan(context, patient);
  }

  void _showBilanDialog(
      BuildContext context,
      String patientName,
      String bilan,
      Map stats,
      ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: purpleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: purpleColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bilan IA — $patientName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: purpleColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: purpleColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statChip('${stats['total']}', 'Total', purpleColor),
                      _statChip('${stats['real']}', 'Confirmées', dangerColor),
                      _statChip('${stats['falseAlerts']}', 'Mineures', warningColor),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    bilan,
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showPatientDetails(
      BuildContext context,
      Map<String, dynamic> patient,
      BuildContext parentContext,
      ) {
    final location = patient['location'] as Map<String, dynamic>? ?? {};
    final isConnected = patient['isConnected'] == true;
    final batteryLevel = (patient['batteryLevel'] as int?) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 35,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.elderly, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['patientName'] ?? 'Patient inconnu',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'CIN : ${patient['cin'] ?? 'Non renseignée'}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(
                    isConnected ? 'Connecté' : 'Hors-ligne',
                    isConnected ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _infoBox(
                icon: Icons.location_on_outlined,
                title: 'Localisation',
                content: location['city'] ?? 'Ville inconnue',
                color: Colors.teal,
              ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _checkAndShowBilan(parentContext, patient);
                  },
                  icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                  label: const Text(
                    'Générer / consulter le bilan IA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: RefreshIndicator(
            color: primaryColor,
            onRefresh: () async {
              setState(() {});
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icons/hiring-process.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bonjour, ${widget.user.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Centre de surveillance patient',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Se déconnecter',
                          onPressed: _confirmLogout,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildQuickStats(),
                      const SizedBox(height: 16),

                      _buildPatientsMapPreview(),
                      const SizedBox(height: 16),

                      _buildPatientListForAI(),
                      const SizedBox(height: 16),

                      _buildMenuGrid(context),
                      const SizedBox(height: 16),

                      _buildRecentAlerts(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: primaryColor, size: 20),
            SizedBox(width: 8),
            Text('Déconnexion', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment fermer votre session ?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.signOut();

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bracelets')
          .where('ownerId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, braceletsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('ownerId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, alertsSnap) {
            final bracelets = braceletsSnap.data?.docs ?? [];
            final alerts = alertsSnap.data?.docs ?? [];

            final total = bracelets.length;

            final active = bracelets.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isConnected'] == true;
            }).length;

            final offline = total - active;

            final urgencies = alerts.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = _extractAlertDate(data);
              return date != null &&
                  _isLast24Hours(date) &&
                  _isRealEmergency(data);
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (urgencies > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: dangerColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: dangerColor.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: dangerColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$urgencies urgence(s) dans les dernières 24h',
                            style: const TextStyle(
                              color: dangerColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _sectionTitle(
                  Icons.monitor_heart_outlined,
                  'Résumé de surveillance',
                ),

                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2, // ✅ toujours 2 en haut + 2 en bas
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55, // ✅ plus large et confortable
                  children: [
                    _buildStatCard(
                      'Patients',
                      total.toString(),
                      Icons.groups_2_outlined,
                      primaryColor,
                    ),
                    _buildStatCard(
                      'Urgences 24h',
                      urgencies.toString(),
                      Icons.emergency_outlined,
                      dangerColor,
                    ),
                    _buildStatCard(
                      'Actifs',
                      active.toString(),
                      Icons.sensors,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Hors-ligne',
                      offline.toString(),
                      Icons.sensors_off_outlined,
                      warningColor,
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPatientsMapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.map_outlined, 'Localisation des patients'),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bracelets')
              .where('ownerId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyBox(
                icon: Icons.map_outlined,
                title: 'Aucune position',
                subtitle: 'Aucun patient affecté à afficher sur la carte.',
              );
            }

            final patientsWithPosition = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final location = data['location'];

              if (location is! Map) return false;

              final lat = _toDouble(location['lat']);
              final lon = _toDouble(location['lon'] ?? location['lng']);

              if (lat == null || lon == null) return false;
              if (lat == 0.0 && lon == 0.0) return false;

              return true;
            }).toList();

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientsMapScreen(user: widget.user),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 175,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: primaryColor,
                        size: 42,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Carte interactive',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${patientsWithPosition.length} patient(s) avec position GPS',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Ouvrir la carte',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  Widget _buildPatientListForAI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.elderly_outlined, 'Patients sous surveillance'),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Rechercher un patient…',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, size: 18, color: primaryColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bracelets')
              .where('ownerId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyBox(
                icon: Icons.person_off_outlined,
                title: 'Aucun patient assigné',
                subtitle: "Contactez l'administrateur.",
              );
            }

            final filtered = snapshot.data!.docs.where((doc) {
              if (_searchQuery.isEmpty) return true;

              final data = doc.data() as Map<String, dynamic>;
              final name = (data['patientName'] ?? '').toString().toLowerCase();
              final cin = (data['cin'] ?? '').toString().toLowerCase();

              return name.contains(_searchQuery) || cin.contains(_searchQuery);
            }).toList();

            if (filtered.isEmpty) {
              return _emptyBox(
                icon: Icons.search_off,
                title: 'Aucun résultat',
                subtitle: 'Aucun patient correspond à "$_searchQuery".',
              );
            }

            return SizedBox(
              height: 170,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return _buildPatientCard({
                    ...data,
                    'id': doc.id,
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final isConnected = patient['isConnected'] == true;
    final location = patient['location'] as Map<String, dynamic>? ?? {};
    final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
    final batteryLevel = (patient['batteryLevel'] as int?) ?? 0;

    return InkWell(
      onTap: () => _showPatientDetails(context, patient, context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 185,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected
                ? Colors.green.withOpacity(0.25)
                : Colors.red.withOpacity(0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: primaryColor,
                    size: 17,
                  ),
                ),
                const Spacer(),
                _statusBadge(
                  isConnected ? 'Actif' : 'Hors-ligne',
                  isConnected ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              patient['patientName'] ?? 'Patient inconnu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              'CIN : ${patient['cin'] ?? 'N/A'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.8, color: Colors.grey[700]),
            ),
            const SizedBox(height: 2),
            Text(
              '${medical['age'] ?? '?'} ans • ${location['city'] ?? 'Ville inconnue'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.8, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _getBatteryIcon(batteryLevel),
                  size: 13,
                  color: _getBatteryColor(batteryLevel),
                ),
                const SizedBox(width: 4),
                Text(
                  '$batteryLevel%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _getBatteryColor(batteryLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.psychology_alt_outlined, size: 13, color: purpleColor),
                const SizedBox(width: 4),
                Text(
                  'Bilan IA',
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.dashboard_customize_outlined, 'Actions rapides'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 380;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isSmall ? 2 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: isSmall ? 1.25 : 0.95,
              children: [
                _buildMenuCard(
                  context,
                  'Historiques',
                  'Anomalies',
                  Icons.history_edu_outlined,
                  Colors.blue,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlertsHistoryScreen(user: widget.user),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  'Dispositifs ',
                  'Bracelets médicaux',
                  Icons.watch_outlined,
                  Colors.green,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BraceletStatusScreen(user: widget.user),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  'Profil',
                  'Paramètres',
                  Icons.manage_accounts_outlined,
                  Colors.grey,
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsScreen(user: widget.user),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          Icons.notification_important_outlined,
          'Anomalies des dernières 24h',
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('ownerId', isEqualTo: widget.user.uid)
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _emptyBox(
                icon: Icons.error_outline,
                title: 'Erreur',
                subtitle: 'Vérifiez les index Firebase.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _emptyBox(
                icon: Icons.check_circle_outline,
                title: 'Aucune anomalie récente',
                subtitle: 'Aucune anomalie enregistrée pendant les dernières 24h.',
              );
            }

            final last24hAlerts = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = _extractAlertDate(data);

              if (date == null) return false;

              return _isLast24Hours(date);
            }).toList();

            if (last24hAlerts.isEmpty) {
              return _emptyBox(
                icon: Icons.check_circle_outline,
                title: 'Aucune anomalie sur 24h',
                subtitle: 'Tous les patients sont stables durant les dernières 24h.',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: last24hAlerts.length > 5 ? 5 : last24hAlerts.length,
              itemBuilder: (context, index) {
                final doc = last24hAlerts[index];
                final data = doc.data() as Map<String, dynamic>;

                return _buildAlertCard(data, doc.id);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> data, String alertId) {
    final isEmergency = _isRealEmergency(data);
    final isTreated = data['status']?.toString() == 'TREATED';

    final color = isTreated
        ? Colors.green
        : isEmergency
        ? dangerColor
        : warningColor;

    final probabilityColor = _getProbabilityColor(data['probability']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isTreated
                  ? Icons.check_circle_outline
                  : isEmergency
                  ? Icons.personal_injury_outlined
                  : Icons.info_outline,
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTreated
                      ? 'Alerte traitée'
                      : isEmergency
                      ? 'Anomalie de mouvement détectée'
                      : 'Événement cinématique mineur',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 5),
                _miniInfoLine(
                  Icons.person_outline,
                  data['patientName'] ?? 'Patient inconnu',
                ),
                const SizedBox(height: 3),
                _miniInfoLine(
                  Icons.access_time,
                  _formatDate(data),
                ),
                const SizedBox(height: 3),
                _miniInfoLine(
                  Icons.location_on_outlined,
                  _extractCity(data),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: probabilityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _probabilityPercent(data),
                  style: TextStyle(
                    color: probabilityColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              if (!isTreated) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _markAlertTreated(alertId),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Text(
                      'Traiter',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12.5, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.2, color: Colors.grey[650]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyBox({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: Colors.grey[400]),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
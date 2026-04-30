import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/alert_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'alerts_history_screen.dart';
import 'bracelet_status_screen.dart';
import 'profile_settings_screen.dart';

class SoignantDashboard extends StatefulWidget {
  final UserModel user;
  const SoignantDashboard({super.key, required this.user});

  @override
  State<SoignantDashboard> createState() => _SoignantDashboardState();
}

class _SoignantDashboardState extends State<SoignantDashboard> {
  final _authService = AuthService();

  // ==========================================
  //  FONCTION UTILITAIRE — APPEL GEMINI
  // Un seul endroit pour appeler le backend
  // ==========================================
  Future<String?> _callGemini(BuildContext context, String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('https://fall-detection-backend-7w0h.onrender.com/api/generate-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 90)); //  timeout sur le http directement

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['report'] as String?;
      }
      print('❌ Erreur HTTP: ${response.statusCode} — ${response.body}');
      return null;
    } catch (e) {
      print('❌ _callGemini erreur: $e');
      return null;
    }
  }
  // ==========================================
  //  BILAN GLOBAL — TOUT L'HISTORIQUE
  // Prompt riche : dossier + toutes les chutes
  // ==========================================
  Future<void> _generateGlobalBilan(
      BuildContext context, Map<String, dynamic> patient) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analyse de tout l'historique en cours..."),
            SizedBox(height: 4),
            Text(
              "Cela peut prendre quelques secondes",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      final braceletId = patient['id'] ?? patient['braceletId'] ?? '';
      final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
      final location = patient['location'] as Map<String, dynamic>? ?? {};

      //  Index existe → orderBy fonctionne
      final alertsSnap = await FirebaseFirestore.instance
          .collection('alerts')
          .where('braceletId', isEqualTo: braceletId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final totalFalls = alertsSnap.docs.length;
      final falseAlerts = alertsSnap.docs
          .where((d) => d.data()['status'] == 'FALSE_ALERT')
          .length;
      final realFalls = totalFalls - falseAlerts;

      final fallsDetails = alertsSnap.docs.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final a = entry.value.data();
        final date = a['createdAt'] != null
            ? DateFormat('dd/MM/yyyy HH:mm')
            .format((a['createdAt'] as Timestamp).toDate())
            : 'Inconnue';
        final weather = a['weather'] != null
            ? "${a['weather']['temperature']}°C, "
            "${a['weather']['description']}, "
            "humidité ${a['weather']['humidity']}%"
            : 'Non disponible';
        final confidence = ((a['probability'] ?? 0) * 100).round();
        final status = a['status'] ?? 'NON_TRAITE';
        return "Chute $i — $date\n"
            "  · Météo: $weather\n"
            "  · Confiance IA: $confidence%\n"
            "  · Statut: $status";
      }).join('\n\n');

      final String prompt =
          "Tu es un médecin gériatre expert en prévention des chutes.\n\n"
          "DOSSIER MÉDICAL :\n"
          "Nom           : ${patient['patientName'] ?? 'Inconnu'}\n"
          "Âge           : ${medical['age'] ?? '?'} ans\n"
          "Groupe sanguin: ${medical['bloodType'] ?? 'N/A'}\n"
          "Pathologies   : ${medical['conditions'] ?? 'Aucune'}\n"
          "Médicaments   : ${medical['medications'] ?? 'Aucun'}\n"
          "Ville         : ${location['city'] ?? 'Inconnue'}\n\n"
          "STATISTIQUES :\n"
          "Total chutes : $totalFalls | Confirmées : $realFalls | Fausses alertes : $falseAlerts\n\n"
          "HISTORIQUE DES CHUTES :\n"
          "${fallsDetails.isNotEmpty ? fallsDetails : 'Aucune chute enregistrée.'}\n\n"
          "Rédige un bilan en 4 parties :\n"
          "1. **Évaluation du risque global** (faible/moyen/élevé/critique)\n"
          "2. **Analyse des patterns** (heures, météo, fréquence)\n"
          "3. **3 facteurs de risque principaux** liés au dossier médical\n"
          "4. **5 recommandations concrètes** de prévention\n\n"
          "Sois direct et utile pour un soignant.";

      //  Timeout 60s
      final bilan = await _callGemini(context, prompt);

//  Simple pop — ferme uniquement le dialog
      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;

      if (bilan != null) {
        await FirebaseFirestore.instance
            .collection('bracelets')
            .doc(braceletId)
            .update({
          'lastBilan': bilan,
          'lastBilanDate': FieldValue.serverTimestamp(),
          'lastBilanFallsCount': totalFalls,
          'lastBilanGeneratedBy': widget.user.uid,
        });
        _showBilanDialog(
          context,
          patient['patientName'] ?? 'Patient',
          bilan,
          {'total': totalFalls, 'real': realFalls, 'falseAlerts': falseAlerts},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Timeout — Render se réveille, réessaie dans 30s"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ==========================================
  //  DIALOGS
  // ==========================================
  void _showBilanDialog(
      BuildContext context, String patientName, String bilan, Map stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.summarize, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bilan global — $patientName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statChip('${stats['total']}', 'Total', Colors.purple),
                      _statChip('${stats['real']}', 'Confirmées', Colors.red),
                      _statChip('${stats['falseAlerts']}', 'Fausses', Colors.orange),
                    ],
                  ),
                ),
                Text(bilan, style: const TextStyle(fontSize: 13, height: 1.6)),
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
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ==========================================
  //  BOTTOM SHEET PATIENT
  // ==========================================
  void _showPatientDetails(
      BuildContext context,
      Map<String, dynamic> patient,
      BuildContext parentContext, // ✅ context du dashboard
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... ton header patient existant ...
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.purple, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['patientName'] ?? 'Inconnu',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${patient['medicalRecord']?['age'] ?? '?'} ans • '
                            '${patient['location']?['city'] ?? 'Ville inconnue'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.medical_information, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 6),
                    Text('Dossier médical',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    '🩸 ${patient['medicalRecord']?['bloodType'] ?? 'N/A'}  '
                        '· 💊 ${patient['medicalRecord']?['medications'] ?? 'Aucun'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    '🏥 ${patient['medicalRecord']?['conditions'] ?? 'Aucune pathologie'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bouton Bilan Global
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.purple, width: 1.5),
                  foregroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context); // ferme bottom sheet
                  //  utilise parentContext du dashboard
                  _checkAndShowBilan(parentContext, patient);
                },
                icon: const Icon(Icons.summarize_outlined),
                label: const Text("Bilan global de santé (IA)"),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  Future<void> _checkAndShowBilan(
      BuildContext context, Map<String, dynamic> patient) async {
    final braceletId = patient['id'] ?? patient['braceletId'] ?? '';

    // Vérifier si un bilan existe déjà dans Firestore
    final existingBilan = patient['lastBilan'] as String?;
    final existingBilanDate = patient['lastBilanDate'] as Timestamp?;

    if (existingBilan != null && existingBilan.isNotEmpty) {
      // Bilan existant — demander si afficher ou régénérer
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.summarize, color: Colors.purple),
              SizedBox(width: 8),
              Text('Bilan existant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(
                        'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(existingBilanDate.toDate())}',
                        style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Un bilan existe déjà. Voulez-vous l\'afficher ou en générer un nouveau ?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'afficher'),
              child: const Text('Afficher'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'regenerer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Régénérer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (choice == 'afficher') {
        // Afficher directement sans appeler Gemini
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
      // choice == 'regenerer' → continue vers génération
    }

    // Pas de bilan ou régénération demandée
    _generateGlobalBilan(context, patient);
  }
  // ==========================================
  //  BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'Bonjour, ${widget.user.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 15),
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/hiring-process.png',
                              width: 85, height: 85, fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Déconnexion"),
                          content: const Text("Voulez-vous vraiment vous déconnecter ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Se déconnecter")),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await _authService.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                        }
                      }
                    },
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (widget.user.hasPatient) _buildPatientInfo(),
                    if (widget.user.hasPatient) const SizedBox(height: 24),
                    _buildQuickStats(),
                    const SizedBox(height: 24),
                    if (widget.user.hasPatient) _buildPatientListForAI(),
                    if (widget.user.hasPatient) const SizedBox(height: 24),
                    _buildMenuGrid(context),
                    const SizedBox(height: 24),
                    _buildRecentAlerts(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientListForAI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dossiers Patients (IA)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bracelets')
              .where('ownerId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final bracelets = snapshot.data!.docs;
            if (bracelets.isEmpty) return const Text('Aucun patient actif.');
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: bracelets.length,
                itemBuilder: (context, index) {
                  final b = bracelets[index].data() as Map<String, dynamic>;
                  return InkWell(
                    onTap: () => _showPatientDetails(context, b, context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.psychology, color: Colors.purple, size: 28),
                          ),
                          const SizedBox(height: 8),
                          Text(b['patientName'] ?? 'Inconnu',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Rapport IA', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatientInfo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bracelets')
          .where('ownerId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int patientCount = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[100], shape: BoxShape.circle),
                child: Icon(Icons.people, color: Colors.blue[700], size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Capacité de surveillance', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      patientCount > 0 ? '$patientCount patients actifs' : 'Aucun patient',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .where('ownerId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final totalAlerts = snapshot.data?.docs.length ?? 0;
        final todayAlerts = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          DateTime alertDate;
          if (data['createdAt'] != null) {
            alertDate = (data['createdAt'] as Timestamp).toDate();
          } else if (data['timestamp'] != null) {
            alertDate = DateTime.fromMillisecondsSinceEpoch((data['timestamp'] as int) * 1000);
          } else {
            return false;
          }
          final now = DateTime.now();
          return alertDate.day == now.day && alertDate.month == now.month && alertDate.year == now.year;
        }).length ?? 0;

        return Row(
          children: [
            Expanded(child: _buildStatCard('Total Alertes', totalAlerts.toString(), Icons.notifications_active, Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard("Aujourd'hui", todayAlerts.toString(), Icons.today, Colors.red)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu Principal',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildMenuCard(context, 'Historique', 'Voir toutes les alertes', Icons.history, Colors.blue,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertsHistoryScreen(user: widget.user)))),
            _buildMenuCard(context, 'Bracelet', 'État du bracelet', Icons.watch, Colors.green,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => BraceletStatusScreen(user: widget.user)))),
            // ✅ Navigation vers page dédiée
            _buildMenuCard(context, 'Paramètres', 'Mon profil', Icons.settings, Colors.grey,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(user: widget.user)))),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alertes Récentes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('ownerId', isEqualTo: widget.user.uid)
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Erreur de chargement'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Icon(
                      widget.user.hasPatient ? Icons.check_circle_outline : Icons.info_outline,
                      size: 64,
                      color: widget.user.hasPatient ? Colors.green[300] : Colors.blue[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.user.hasPatient ? 'Aucune alerte' : 'Aucun patient assigné',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.user.hasPatient ? 'Tout va bien pour le moment' : "Contactez l'administrateur",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final alert = AlertModel.fromFirestore(snapshot.data!.docs[index]);
                return _buildAlertCard(alert);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alert.type == 'FALL' ? Colors.red[200]! : Colors.orange[200]!, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: alert.type == 'FALL' ? Colors.red[50] : Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              alert.type == 'FALL' ? Icons.warning_amber_rounded : Icons.info_outline,
              color: alert.type == 'FALL' ? Colors.red : Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type == 'FALL' ? 'Chute détectée' : 'Alerte',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(alert.formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getProbabilityColor(alert.probability).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              alert.probabilityPercent,
              style: TextStyle(color: _getProbabilityColor(alert.probability), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 0.8) return Colors.red;
    if (probability >= 0.5) return Colors.orange;
    return Colors.yellow[700]!;
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'manage_users_screen.dart';
import 'all_alerts_screen.dart';
import 'all_bracelets_screen.dart';
import 'unassigned_patients_screen.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();

  void _showAddBraceletDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddBraceletDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBraceletDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Patient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: const Text(
                    'Administration Centrale',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset('assets/icons/medical-team.png', width: 70, height: 70),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Se déconnecter',
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Row(children: [Icon(Icons.exit_to_app, color: Colors.deepPurple), SizedBox(width: 8), Text("Déconnexion")]),
                          content: const Text("Voulez-vous vraiment fermer votre session admin ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Déconnexion")
                            ),
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
                    _buildGlobalStats(),
                    const SizedBox(height: 30),
                    _buildAdminMenu(context),
                    const SizedBox(height: 30),
                    _buildRecentActivity(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'soignant').snapshots(),
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('alerts').snapshots(),
          builder: (context, alertsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').snapshots(),
              builder: (context, braceletsSnapshot) {
                final totalSoignants = usersSnapshot.data?.docs.length ?? 0;
                final totalAlerts = alertsSnapshot.data?.docs.length ?? 0;
                final totalBracelets = braceletsSnapshot.data?.docs.length ?? 0;
                final activeBracelets = braceletsSnapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isConnected'] == true;
                }).length ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text('Vue d\'ensemble', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard('Soignants', totalSoignants.toString(), Icons.medical_services, Colors.blue),
                        _buildStatCard('Patients', totalBracelets.toString(), Icons.elderly, Colors.green),
                        _buildStatCard('Bracelets Actifs', activeBracelets.toString(), Icons.wifi_tethering, Colors.purple),
                        _buildStatCard('Total Alertes', totalAlerts.toString(), Icons.warning_amber_rounded, Colors.orange),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: color)
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_suggest, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Gestion Système', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 16),

        // Patients sans soignant
        _buildMenuCard(
            context,
            'Patients orphelins',
            'Réaffecter les patients sans soignant',
            Icons.assignment_late,
            Colors.deepOrange, // Couleur rouge/orange pour alerter
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnassignedPatientsScreen()))
        ),

        const SizedBox(height: 16),
        _buildMenuCard(context, 'Réseau Médical', 'Gérer les soignants et affectations', Icons.local_hospital, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
        const SizedBox(height: 12),
        _buildMenuCard(context, 'Registre des Chutes', 'Consulter l\'historique global', Icons.history_edu, Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllAlertsScreen()))),
        const SizedBox(height: 12),
        _buildMenuCard(context, 'Parc Appareils', 'Surveiller tous les bracelets connectés', Icons.watch_rounded, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBraceletsScreen()))),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.shade100)
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
                    borderRadius: BorderRadius.circular(16)
                ),
                child: Icon(icon, size: 28, color: Colors.white)
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))
                    ]
                )
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Dernières Urgences', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('alerts').orderBy('timestamp', descending: true).limit(5).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
                          const SizedBox(height: 12),
                          const Text('Aucune urgence récente', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      )
                  )
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) => _buildActivityItem(snapshot.data!.docs[index].data() as Map<String, dynamic>),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data) {
    final conf = (data['probability'] ?? 0) * 100;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: const Icon(Icons.personal_injury, color: Colors.red, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['patientName'] ?? 'Patient inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('Type : ${data['type'] ?? 'Inconnu'}', style: TextStyle(fontSize: 13, color: Colors.grey[600]))
                  ]
              )
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20)
            ),
            child: Text('IA: ${conf.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// DIALOGUE AJOUT PATIENT (MISE À JOUR)
// =======================================================
class AddBraceletDialog extends StatefulWidget {
  const AddBraceletDialog({super.key});

  @override
  State<AddBraceletDialog> createState() => _AddBraceletDialogState();
}

class _AddBraceletDialogState extends State<AddBraceletDialog> {
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedSoignantId;
  String? _selectedSoignantName;
  bool _isLoading = false;

  void _saveBracelet() async {
    if (_patientNameController.text.isEmpty || _selectedSoignantId == null || _ageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir le nom, l\'âge et choisir un soignant'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🌟 Génération d'un ID de bracelet unique et automatique
      final newBraceletRef = FirebaseFirestore.instance.collection('bracelets').doc();

      await newBraceletRef.set({
        'braceletId': newBraceletRef.id,
        'ownerId': _selectedSoignantId,
        'ownerName': _selectedSoignantName, // 🌟 LE NOM DU SOIGNANT EST BIEN SAUVEGARDÉ ICI
        'patientName': _patientNameController.text.trim(),
        'batteryLevel': 100,
        'isConnected': false,
        'lastUpdate': FieldValue.serverTimestamp(),
        // 🌟 La localisation par défaut en attendant la mise à jour de l'API de l'ESP32
        'location': {
          'city': 'En attente...',
          'lat': 0.0,
          'lon': 0.0,
        },
        'medicalRecord': {
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'conditions': '',
          'medications': '',
          'bloodType': '',
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Patient ajouté ! ID : ${newBraceletRef.id}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(
        children: [
          Icon(Icons.elderly, color: Colors.deepPurple, size: 40),
          SizedBox(height: 8),
          Text('Nouveau Patient', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enregistrez un nouveau patient et affectez-lui un soignant superviseur. La ville sera détectée automatiquement au branchement de l'appareil.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _patientNameController,
              decoration: InputDecoration(
                labelText: 'Nom du patient',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Âge du patient', filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.cake, color: Colors.deepPurple),
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'soignant').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final soignants = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Soignant Responsable',
                    filled: true,
                    fillColor: Colors.deepPurple.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.medical_information, color: Colors.deepPurple),
                  ),
                  value: _selectedSoignantId,
                  items: soignants.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSoignantId = val;
                      // C'est ici qu'on récupère le nom du soignant pour l'enregistrer !
                      _selectedSoignantName = soignants.firstWhere((doc) => doc.id == val)['name'];
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBracelet,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
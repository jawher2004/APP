import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'manage_users_screen.dart';
import 'all_alerts_screen.dart';
import 'all_bracelets_screen.dart';
import 'unassigned_patients_screen.dart';
import 'admin_patients_map_screen.dart';
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
        backgroundColor: const Color(0xFF004D40),
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF004D40).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF004D40),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: const Text(
                    'Console de Supervision',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00695C), Color(0xFF004D40)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hub_outlined, color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 12),
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
                          title: const Row(children: [Icon(Icons.exit_to_app, color: Color(0xFF004D40)), SizedBox(width: 8), Text("Déconnexion")]),
                          content: const Text("Voulez-vous vraiment fermer la session superviseur ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Déconnexion")),
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
                padding: const EdgeInsets.all(12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildGlobalStats(),
                    const SizedBox(height: 20),
                    _buildAdminMenu(context),
                    const SizedBox(height: 20),
                    _buildRecentActivity(),
                    const SizedBox(height: 60),
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

                int activeBracelets = 0;
                int offlineBracelets = 0;
                if (braceletsSnapshot.hasData) {
                  for (var doc in braceletsSnapshot.data!.docs) {
                    final b = doc.data() as Map<String, dynamic>;
                    if (b['isConnected'] == true) {
                      activeBracelets++;
                    } else {
                      offlineBracelets++;
                    }
                  }
                }

                int anomaliesToday = 0;
                if (alertsSnapshot.hasData) {
                  final now = DateTime.now();
                  for (var doc in alertsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['isFalseAlarm'] == false || data['isFalseAlarm'] == null) {
                      final timestamp = data['timestamp'];
                      DateTime? alertDate;
                      if (timestamp is Timestamp) {
                        alertDate = timestamp.toDate();
                      } else if (timestamp is int) {
                        alertDate = DateTime.fromMillisecondsSinceEpoch(
                            timestamp.toString().length == 10 ? timestamp * 1000 : timestamp);
                      }
                      if (alertDate != null &&
                          alertDate.year == now.year &&
                          alertDate.month == now.month &&
                          alertDate.day == now.day) {
                        anomaliesToday++;
                      }
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Color(0xFF004D40)),
                        const SizedBox(width: 8),
                        Text('Supervision Opérationnelle',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.45,
                      children: [
                        _buildStatCard('Urgences (24h)', anomaliesToday.toString(), Icons.warning_rounded, const Color(0xFFA32D2D)),
                        _buildStatCard('Patients Surveillés', activeBracelets.toString(), Icons.monitor_heart, const Color(0xFF2E7D32)),
                        _buildStatCard('Bracelets Hors-ligne', offlineBracelets.toString(), Icons.portable_wifi_off, const Color(0xFFE65100)),
                        _buildStatCard('Effectif Médical', totalSoignants.toString(), Icons.medical_services, const Color(0xFF534AB7)),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: color)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 1),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
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
            const Icon(Icons.settings_input_component, color: Color(0xFF004D40)),
            const SizedBox(width: 8),
            Text('Outils de Supervision',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 10),
        _buildMenuCard(context, 'Registre', 'Historique des anomalies IA', Icons.history_edu,
            const Color(0xFFA32D2D),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllAlertsScreen()))),
        const SizedBox(height: 8),
        _buildMenuCard(context, 'Réseau Médical', 'Gérer les accès du personnel', Icons.local_hospital,
            const Color(0xFF534AB7),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
        const SizedBox(height: 8),
        _buildMenuCard(context, 'Supervision des dispositifs', 'Dossiers patients et appareils', Icons.watch_rounded,
            const Color(0xFF00796B),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBraceletsScreen()))),
        const SizedBox(height: 8),
        _buildMenuCard(
          context,
          'Carte Patients',
          'Localisation globale des patients',
          Icons.map_outlined,
          const Color(0xFF00695C),
              () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminPatientsMapScreen(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildMenuCard(context, 'Patients en attente', 'Affectations urgentes', Icons.assignment_late,
            const Color(0xFFE65100),
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnassignedPatientsScreen()))),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                    ])),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[300], size: 14),
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
            const Icon(Icons.sensors, color: Color(0xFFA32D2D)),
            const SizedBox(width: 8),
            Text('Dernières Anomalies',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('isFalseAlarm', isEqualTo: false)
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.gpp_good_outlined, size: 40, color: Colors.green[300]),
                          const SizedBox(height: 10),
                          const Text('Aucune anomalie critique récente',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      )));
            }
            return Column(
              children: snapshot.data!.docs
                  .map((doc) => _buildActivityItem(doc.data() as Map<String, dynamic>))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data) {
    final conf = (data['probability'] ?? 0) * 100;

    String location = 'Inconnue';
    if (data['weather'] is Map) {
      location = data['weather']['city'] ?? 'Inconnue';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA32D2D).withOpacity(0.3)),
          boxShadow: [BoxShadow(color: const Color(0xFFA32D2D).withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: Color(0xFFFCEBEB), shape: BoxShape.circle),
              child: const Icon(Icons.priority_high, color: Color(0xFFA32D2D), size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['patientName'] ?? 'Sujet inconnu',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 11, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(location, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    )
                  ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFA32D2D), borderRadius: BorderRadius.circular(10)),
            child: Text('IA: ${conf.toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// DIALOGUE AJOUT PATIENT (AVEC TRANSFERT CIN BLUETOOTH)
// =======================================================
class AddBraceletDialog extends StatefulWidget {
  const AddBraceletDialog({super.key});

  @override
  State<AddBraceletDialog> createState() => _AddBraceletDialogState();
}

class _AddBraceletDialogState extends State<AddBraceletDialog> {
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cinController = TextEditingController();

  String? _selectedSoignantId;
  String? _selectedSoignantName;
  bool _isLoading = false;
  bool _isBraceletPaired = false;

  void _simulatePairing() async {
    if (_cinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Veuillez d\'abord saisir la CIN du patient avant d\'appairer le bracelet.'),
          backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 16),
            const Text("Connexion au capteur BLE...", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Transfert de la CIN (${_cinController.text}) dans l'EEPROM...",
                style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      Navigator.pop(context);
      setState(() => _isBraceletPaired = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ CIN enregistrée dans le bracelet avec succès !'), backgroundColor: Colors.green));
    }
  }

  void _saveBracelet() async {
    if (!_isBraceletPaired) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Veuillez transférer la CIN au capteur via Bluetooth.'),
          backgroundColor: Colors.orange));
      return;
    }

    if (_patientNameController.text.isEmpty || _selectedSoignantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newBraceletRef = FirebaseFirestore.instance.collection('bracelets').doc();

      await newBraceletRef.set({
        'braceletId': newBraceletRef.id,
        'ownerId': _selectedSoignantId,
        'ownerName': _selectedSoignantName,
        'patientName': _patientNameController.text.trim(),
        'cin': _cinController.text.trim(),
        'batteryLevel': 100,
        'isConnected': true,
        'lastUpdate': FieldValue.serverTimestamp(),
        'location': {'city': 'En attente...', 'lat': 0.0, 'lon': 0.0},
        'medicalRecord': {
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'conditions': '',
          'medications': '',
          'bloodType': ''
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Patient ajouté au réseau !'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
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
          Icon(Icons.elderly, color: Color(0xFF004D40), size: 40),
          SizedBox(height: 8),
          Text('Nouveau Patient', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _patientNameController,
              decoration: InputDecoration(
                  labelText: 'Nom du patient',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF004D40))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cinController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'CIN du patient',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.badge, color: Color(0xFF004D40))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Âge du patient',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.cake, color: Color(0xFF004D40))),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _isBraceletPaired ? null : _simulatePairing,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: _isBraceletPaired ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _isBraceletPaired ? Colors.green : Colors.blue, width: 1.5)),
                child: Column(
                  children: [
                    Icon(_isBraceletPaired ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                        color: _isBraceletPaired ? Colors.green : Colors.blue, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      _isBraceletPaired ? 'CIN Transférée au capteur ✅' : '🔗 Envoyer la CIN au capteur',
                      style: TextStyle(
                          color: _isBraceletPaired ? Colors.green : Colors.blue,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'soignant')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final soignants = snapshot.data!.docs;

                return Autocomplete<QueryDocumentSnapshot>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
                    return soignants.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['name'] ?? '')
                          .toString()
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) ||
                          (data['cin'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  displayStringForOption: (option) =>
                  '${(option.data() as Map<String, dynamic>)['name']} - CIN: ${(option.data() as Map<String, dynamic>)['cin'] ?? 'N/A'}',
                  onSelected: (selection) => setState(() {
                    _selectedSoignantId = selection.id;
                    _selectedSoignantName = (selection.data() as Map<String, dynamic>)['name'];
                  }),
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                          labelText: 'Affecter un soignant',
                          filled: true,
                          fillColor: const Color(0xFF004D40).withOpacity(0.05),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40))),
                    );
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
            child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBracelet,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
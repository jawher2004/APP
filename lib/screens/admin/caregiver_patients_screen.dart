import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverPatientsScreen extends StatefulWidget {
  final String soignantId;
  final String soignantName;

  const CaregiverPatientsScreen({super.key, required this.soignantId, required this.soignantName});

  @override
  State<CaregiverPatientsScreen> createState() => _CaregiverPatientsScreenState();
}

class _CaregiverPatientsScreenState extends State<CaregiverPatientsScreen> {
  String searchQuery = '';

  // 🌟 FONCTION POUR DÉSAFFECTER LE PATIENT
  void _unassignPatient(String braceletId, String patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce patient ?', style: TextStyle(color: Colors.deepOrange)),
        content: Text('Voulez-vous retirer $patientName de la charge du Dr. ${widget.soignantName} ?\nLe patient sera placé dans la liste des "Patients Orphelins".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).update({
                'ownerId': 'NON_AFFECTE',
                'ownerName': 'Aucun soignant',
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient retiré et mis en attente !'), backgroundColor: Colors.orange));
              }
            },
            child: const Text('Retirer l\'affectation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(title: Text('Patients de ${widget.soignantName}'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un patient (Nom ou CIN)...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: widget.soignantId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Aucun patient affecté.'));

                final patients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '').toString().toLowerCase();
                  final cin = (data['cin'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || cin.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final p = patients[index].data() as Map<String, dynamic>;
                    final braceletId = patients[index].id;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.deepPurpleAccent, child: Icon(Icons.elderly, color: Colors.white)),
                        title: Text(p['patientName'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('CIN: ${p['cin'] ?? 'Non renseignée'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.deepOrange),
                          tooltip: 'Retirer du soignant',
                          onPressed: () => _unassignPatient(braceletId, p['patientName'] ?? 'Patient'), // 🌟 APPEL DE LA FONCTION
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
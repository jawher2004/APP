import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnassignedPatientsScreen extends StatelessWidget {
  const UnassignedPatientsScreen({super.key});

  void _showAssignDialog(BuildContext context, String braceletId, String patientName) {
    String? selectedSoignantId;
    String? selectedSoignantName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.assignment_ind, color: Colors.deepOrange, size: 40),
            const SizedBox(height: 8),
            Text('Affecter $patientName', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'soignant').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
            final soignants = snapshot.data!.docs;

            if (soignants.isEmpty) {
              return const Text('Aucun soignant disponible dans le système.', style: TextStyle(color: Colors.red));
            }

            return StatefulBuilder(
              builder: (context, setState) {
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Choisir le nouveau Soignant',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.medical_services, color: Colors.deepPurple),
                  ),
                  value: selectedSoignantId,
                  items: soignants.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedSoignantId = val;
                      selectedSoignantName = soignants.firstWhere((doc) => doc.id == val)['name'];
                    });
                  },
                );
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (selectedSoignantId != null) {
                await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).update({
                  'ownerId': selectedSoignantId,
                  'ownerName': selectedSoignantName,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Patient réaffecté avec succès !'), backgroundColor: Colors.green));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Patients à réaffecter', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🌟 On cherche uniquement les bracelets sans soignant !
        stream: FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: 'NON_AFFECTE').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  const Text('Tout est en ordre !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('Tous les patients ont un soignant.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final unassignedPatients = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unassignedPatients.length,
            itemBuilder: (context, index) {
              final patient = unassignedPatients[index].data() as Map<String, dynamic>;
              final braceletId = unassignedPatients[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                  ),
                  title: Text(patient['patientName'] ?? 'Patient inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('Aucun soignant affecté', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  trailing: ElevatedButton(
                    onPressed: () => _showAssignDialog(context, braceletId, patient['patientName'] ?? 'Patient'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Affecter'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
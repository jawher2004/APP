import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnassignedPatientsScreen extends StatefulWidget {
  const UnassignedPatientsScreen({super.key});

  @override
  State<UnassignedPatientsScreen> createState() => _UnassignedPatientsScreenState();
}

class _UnassignedPatientsScreenState extends State<UnassignedPatientsScreen> {
  String searchQuery = ''; // État de la recherche des patients orphelins

  // 🌟 NOUVEAU : DIALOGUE D'AFFECTATION INTELLIGENT (Avec Autocomplete)
  void _showAssignDialog(BuildContext context, String braceletId, String patientName) {
    String? selectedSoignantId;
    String? selectedSoignantName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.assignment_ind, color: Color(0xFFE65100), size: 40),
            const SizedBox(height: 8),
            Text('Affecter $patientName', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'soignant').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: Color(0xFFE65100))));
            final soignants = snapshot.data!.docs;

            if (soignants.isEmpty) {
              return const Text('Aucun soignant disponible dans le système.', style: TextStyle(color: Colors.red));
            }

            return StatefulBuilder(
              builder: (context, setStateLocal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Recherchez un soignant pour prendre en charge ce patient :', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    // L'Autocomplete intelligent au lieu du menu déroulant !
                    Autocomplete<QueryDocumentSnapshot>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<QueryDocumentSnapshot>.empty();
                        return soignants.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final cin = (data['cin'] ?? '').toString().toLowerCase();
                          final query = textEditingValue.text.toLowerCase();
                          return name.contains(query) || cin.contains(query);
                        });
                      },
                      displayStringForOption: (QueryDocumentSnapshot option) {
                        final data = option.data() as Map<String, dynamic>;
                        return '${data['name']} - CIN: ${data['cin'] ?? 'N/A'}';
                      },
                      onSelected: (selection) {
                        setStateLocal(() {
                          selectedSoignantId = selection.id;
                          selectedSoignantName = (selection.data() as Map<String, dynamic>)['name'];
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        return TextField(
                          controller: controller, focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Rechercher (Nom ou CIN)',
                            filled: true, fillColor: Colors.orange.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFE65100)),
                          ),
                        );
                      },
                    ),

                    if (selectedSoignantName != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Sélectionné : Dr. $selectedSoignantName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )
                    ]
                  ],
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un soignant.'), backgroundColor: Colors.orange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            child: const Text('Confirmer l\'affectation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Fond clair
      appBar: AppBar(
        title: const Text('Patients en attente', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE65100), // Orange profond
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🌟 BARRE DE RECHERCHE DES PATIENTS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un patient (Nom ou CIN)...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE65100)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: 'NON_AFFECTE').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                        const SizedBox(height: 16),
                        const Text('Tout est en ordre !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Text('Tous les patients ont un soignant attribué.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // Filtrage dynamique
                final unassignedPatients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['patientName'] ?? '').toString().toLowerCase();
                  final cin = (data['cin'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || cin.contains(searchQuery);
                }).toList();

                if (unassignedPatients.isEmpty) {
                  return const Center(child: Text('Aucun patient trouvé avec cette recherche.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: unassignedPatients.length,
                  itemBuilder: (context, index) {
                    final patient = unassignedPatients[index].data() as Map<String, dynamic>;
                    final braceletId = unassignedPatients[index].id;
                    final cinDisplay = patient['cin'] ?? 'Non renseignée';

                    // 🌟 CARTE D'AFFECTATION (Design Pro)
                    return Card(
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
                                    color: const Color(0xFFFFF3E0), // Orange très clair
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person_off_outlined, color: Color(0xFFE65100), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patient['patientName'] ?? 'Patient inconnu',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text('CIN: $cinDisplay', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFE65100)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Orphelin (Attente d\'affectation)',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 0.5, thickness: 0.5),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => _showAssignDialog(context, braceletId, patient['patientName'] ?? 'Patient'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE65100),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_add_alt_1, size: 16, color: Colors.white),
                                        SizedBox(width: 6),
                                        Text('Attribuer un soignant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
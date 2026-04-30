import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllBraceletsScreen extends StatelessWidget {
  const AllBraceletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tous les Bracelets'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bracelets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun bracelet enregistré.'));
          }

          final bracelets = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bracelets.length,
            itemBuilder: (context, index) {
              final b = bracelets[index].data() as Map<String, dynamic>;
              final braceletId = bracelets[index].id;
              final isConnected = b['isConnected'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Dossier : ${b['patientName']}'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Soignant responsable : ${b['ownerName']}'),
                            const Divider(),
                            Text('Âge : ${b['medicalRecord']?['age'] ?? 'Non défini'} ans'),
                            Text('Groupe Sanguin : ${b['medicalRecord']?['bloodType'] ?? 'Non défini'}'),
                            const SizedBox(height: 8),
                            const Text('Antécédents :', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${b['medicalRecord']?['conditions'] ?? 'Aucun'}'),
                            const SizedBox(height: 8),
                            const Text('Traitements en cours :', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${b['medicalRecord']?['medications'] ?? 'Aucun'}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fermer'),
                          )
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Icône statut de connexion
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green[50] : Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.watch,
                            color: isConnected ? Colors.green : Colors.red,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Infos
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['patientName'] ?? 'Patient inconnu',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Soignant : ${b['ownerName'] ?? 'Non assigné'}',
                                style: TextStyle(color: Colors.deepPurple[700], fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Batterie : ${b['batteryLevel'] ?? 0}% | Ville : ${b['location']?['city'] ?? 'Non définie'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Bouton Supprimer
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer ?'),
                                content: Text('Voulez-vous supprimer le bracelet de ${b['patientName']} ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).delete();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ), // <-- C'est cette parenthèse qui manquait !
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
class ManageUsersScreen extends StatelessWidget {
  const ManageUsersScreen({super.key});

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(); // 🌟 NOUVEAU CHAMP MOT DE PASSE

    showDialog(
      context: context,
      barrierDismissible: false, // Empêche de fermer pendant le chargement
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.medical_services, color: Colors.deepPurple, size: 40),
            SizedBox(height: 8),
            Text('Nouveau Soignant', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: 'Nom complet du Dr.', filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.person, color: Colors.deepPurple)
                  )
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: 'Email de connexion', filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.email, color: Colors.deepPurple)
                  )
              ),
              const SizedBox(height: 12),
              TextField( // 🌟 CHAMP MOT DE PASSE
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Mot de passe (Min. 6 car.)', filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple)
                  )
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty && passCtrl.text.length >= 6) {
                try {
                  // Affiche un indicateur visuel (Optionnel, bloque l'interface en attendant)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Création du compte en cours...')));

                  // 🌟 ASTUCE PRO : Créer une 2ème instance Firebase pour ne pas déconnecter l'Admin
                  FirebaseApp tempApp = await Firebase.initializeApp(
                    name: 'TempAuthApp',
                    options: Firebase.app().options,
                  );

                  // 1. On crée le VRAI compte d'authentification
                  UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
                      .createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());

                  String newUid = userCredential.user!.uid;

                  // On supprime l'instance temporaire
                  await tempApp.delete();

                  // 2. On enregistre le profil dans Firestore avec le VRAI UID
                  await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                    'uid': newUid,
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'role': 'soignant',
                    'fcmToken': '',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Soignant créé avec succès !'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${e.toString()}'), backgroundColor: Colors.red));
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remplissez tout (Mot de passe > 6 caractères)'), backgroundColor: Colors.orange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Créer le compte'),
          ),
        ],
      ),
    );
  }


  // NOUVEAU : Fonction de suppression avec gestion des patients orphelins
  void _confirmDeleteUser(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce soignant ?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment retirer le Dr. $name du réseau médical ?\n\nSi des patients lui sont affectés, ils seront mis en attente d\'un nouveau soignant.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  // 1. Chercher tous les bracelets (patients) affectés à ce soignant
                  final braceletsQuery = await FirebaseFirestore.instance
                      .collection('bracelets')
                      .where('ownerId', isEqualTo: docId)
                      .get();

                  // 2. Si le soignant a des patients, on les "libère" au lieu de les supprimer
                  for (var doc in braceletsQuery.docs) {
                    await doc.reference.update({
                      'ownerId': 'NON_AFFECTE',
                      'ownerName': 'Aucun soignant',
                    });
                  }

                  // 3. Supprimer le soignant de Firestore
                  await FirebaseFirestore.instance.collection('users').doc(docId).delete();

                  // 4. (Optionnel) Tenter de le supprimer de l'Auth si on a les droits
                  // Note: Côté mobile, on ne peut généralement supprimer qu'un compte connecté.
                  // La suppression Firestore suffit pour lui bloquer l'accès aux données.

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Soignant supprimé. ${braceletsQuery.docs.length} patient(s) mis en attente.'),
                            backgroundColor: Colors.orange
                        )
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Supprimer')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Fond gris très clair moderne
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Ajouter un Soignant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      appBar: AppBar(
        title: const Text('Réseau Médical', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun personnel enregistré.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final isSoignant = user['role'] == 'soignant';

              return GestureDetector(
                onLongPress: () {
                  if (isSoignant) {
                    _confirmDeleteUser(context, userId, user['name'] ?? 'Inconnu');
                  }
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0, // Suppression de l'ombre classique
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSoignant ? Colors.deepPurple.withOpacity(0.2) : Colors.grey.shade300, width: 1.5)
                    ),
                    child: ExpansionTile(
                      shape: const Border(), // Retire les lignes moches lors du clic
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: isSoignant ? Colors.deepPurple.withOpacity(0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Icon(
                          isSoignant ? Icons.medical_services_outlined : Icons.admin_panel_settings,
                          color: isSoignant ? Colors.deepPurple : Colors.grey[700],
                          size: 28,
                        ),
                      ),
                      title: Text(
                        user['name'] ?? 'Utilisateur',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: isSoignant ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8)
                              ),
                              child: Text(
                                  user['role']?.toUpperCase() ?? 'INCONNU',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSoignant ? Colors.blue[700] : Colors.grey[700])
                              ),
                            ),
                          ],
                        ),
                      ),
                      children: [
                        if (isSoignant)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('bracelets')
                                .where('ownerId', isEqualTo: userId)
                                .snapshots(),
                            builder: (context, braceletSnap) {
                              if (!braceletSnap.hasData) return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());

                              final bracelets = braceletSnap.data!.docs;

                              if (bracelets.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.05)),
                                  child: const Text('Aucun patient affecté à ce soignant.', style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
                                );
                              }

                              return Container(
                                decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.02),
                                    border: Border(top: BorderSide(color: Colors.deepPurple.withOpacity(0.1)))
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
                                      child: Text('Patients en charge :', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.deepPurple, fontSize: 12)),
                                    ),
                                    ...bracelets.map((doc) {
                                      final b = doc.data() as Map<String, dynamic>;
                                      final isConnected = b['isConnected'] == true;
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                        leading: const Icon(Icons.elderly, color: Colors.deepPurple, size: 24),
                                        title: Text(b['patientName'] ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text(b['location']?['city'] ?? 'Ville inconnue', style: const TextStyle(fontSize: 12)),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12)
                                          ),
                                          child: Text(
                                            isConnected ? 'Connecté' : 'Hors ligne',
                                            style: TextStyle(color: isConnected ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
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
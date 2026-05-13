import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'caregiver_patients_screen.dart'; // N'oublie pas de créer ce fichier si ce n'est pas fait !

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String searchQuery = ''; // État pour la barre de recherche

  void _showAddUserDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final cinCtrl = TextEditingController(); // 🌟 CHAMP CIN

    showDialog(
      context: context,
      barrierDismissible: false,
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
              TextField( // 🌟 CHAMP CIN
                  controller: cinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Numéro CIN', filled: true, fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.badge, color: Colors.deepPurple)
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
              TextField(
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
              if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty && passCtrl.text.length >= 6 && cinCtrl.text.isNotEmpty) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Création du compte en cours...')));

                  FirebaseApp tempApp = await Firebase.initializeApp(
                    name: 'TempAuthApp',
                    options: Firebase.app().options,
                  );

                  UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
                      .createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());

                  String newUid = userCredential.user!.uid;
                  await tempApp.delete();

                  await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                    'uid': newUid,
                    'name': nameCtrl.text.trim(),
                    'cin': cinCtrl.text.trim(),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remplissez tous les champs'), backgroundColor: Colors.orange));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Créer le compte'),
          ),
        ],
      ),
    );
  }

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
                  final braceletsQuery = await FirebaseFirestore.instance.collection('bracelets').where('ownerId', isEqualTo: docId).get();
                  for (var doc in braceletsQuery.docs) {
                    await doc.reference.update({'ownerId': 'NON_AFFECTE', 'ownerName': 'Aucun soignant'});
                  }
                  await FirebaseFirestore.instance.collection('users').doc(docId).delete();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Soignant supprimé. ${braceletsQuery.docs.length} patient(s) mis en attente.'), backgroundColor: Colors.orange));
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
        backgroundColor: const Color(0xFF534AB7),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Ajouter un Soignant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      appBar: AppBar(
        title: const Text('Réseau Médical', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF534AB7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🌟 BARRE DE RECHERCHE INTELLIGENTE
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou CIN...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF534AB7)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aucun personnel enregistré.'));
                }

                // Filtrage dynamique
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final cin = (data['cin'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery) || cin.contains(searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('Aucun résultat trouvé.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final isSoignant = user['role'] == 'soignant';

                    // 🌟 TA MAGNIFIQUE CARTE INTÉGRÉE ICI
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: Column(
                        children: [
                          // — En-tête de la carte
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Row(
                              children: [
                                // Avatar avec icône
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSoignant ? const Color(0xFFEEEDFE) : const Color(0xFFF1EFE8),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isSoignant ? Icons.medical_services_outlined : Icons.shield_outlined,
                                    color: isSoignant ? const Color(0xFF534AB7) : const Color(0xFF5F5E5A),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nom + badge rôle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['name'] ?? 'Utilisateur',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSoignant ? const Color(0xFFEEEDFE) : const Color(0xFFF1EFE8),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isSoignant ? Icons.how_to_reg_outlined : Icons.lock_outline,
                                              size: 12,
                                              color: isSoignant ? const Color(0xFF3C3489) : const Color(0xFF444441),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isSoignant ? 'Soignant' : 'Admin',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isSoignant ? const Color(0xFF3C3489) : const Color(0xFF444441),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bouton supprimer (soignant uniquement)
                                if (isSoignant)
                                  GestureDetector(
                                    onTap: () => _confirmDeleteUser(context, userId, user['name'] ?? 'Inconnu'),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFCEBEB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFF7C1C1), width: 0.5),
                                      ),
                                      child: const Icon(Icons.delete_outline, color: Color(0xFFA32D2D), size: 18),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // — Séparateur
                          const Divider(height: 0.5, thickness: 0.5),

                          // — Pied de carte
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              children: [
                                if (isSoignant) ...[
                                  const Icon(Icons.badge_outlined, size: 15, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('CIN : ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                  Text(
                                    user['cin'] ?? 'Non renseigné',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),

                                  // 🌟 BOUTON POUR VOIR LES PATIENTS
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CaregiverPatientsScreen(
                                            soignantId: userId,
                                            soignantName: user['name'] ?? 'Soignant',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEEDFE),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.group_outlined, size: 14, color: Color(0xFF3C3489)),
                                          SizedBox(width: 6),
                                          Text('Gérer les patients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF3C3489))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Accès complet au système', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                ],
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/alert_model.dart';
import '../soignant/alert_details_screen.dart'; // 🌟 On réutilise ton bel écran !

class AllAlertsScreen extends StatelessWidget {
  const AllAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Historique Global'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('Aucune alerte dans le système.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              // 🌟 On transforme le document Firestore en AlertModel
              final alert = AlertModel.fromFirestore(docs[index]);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[50],
                    child: const Icon(Icons.warning, color: Colors.red),
                  ),
                  title: Text('Patient : ${alert.patientName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Le ${DateFormat('dd/MM/yyyy à HH:mm').format(alert.createdAt)}\nType : ${alert.type}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () {
                    // 🌟 L'Admin a accès à tous les détails (Météo, IA) !
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AlertDetailsScreen(alert: alert)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
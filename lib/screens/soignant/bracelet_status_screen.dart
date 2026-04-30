import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart'; // 🌟 NOUVEAU
import 'package:latlong2/latlong.dart'; // 🌟 NOUVEAU
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/bracelet_model.dart';
import 'edit_patient_profile_screen.dart';

class BraceletStatusScreen extends StatelessWidget {
  final UserModel user;
  const BraceletStatusScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Mes Patients'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bracelets')
            .where('ownerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aucun patient assigné', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text("Contactez l'administrateur", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            );
          }

          final bracelets = snapshot.data!.docs
              .map((doc) => BraceletModel.fromFirestore(doc))
              .toList();

          return PageView.builder(
            itemCount: bracelets.length,
            itemBuilder: (context, index) {
              return _buildPatientPage(context, bracelets[index], index, bracelets.length);
            },
          );
        },
      ),
    );
  }

  Widget _buildPatientPage(BuildContext context, BraceletModel bracelet, int index, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicateur pagination
          if (total > 1)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Patient ${index + 1} / $total — Swipe pour naviguer',
                      style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Card principale — statut bracelet
          _buildStatusCard(context, bracelet),
          const SizedBox(height: 16),

          // 🌟 NOUVELLE CARD : CARTE GÉOGRAPHIQUE
          _buildMapCard(context, bracelet),

          // Card dossier médical
          _buildMedicalCard(context, bracelet),
          const SizedBox(height: 16),

          // Card infos techniques
          _buildInfoCard(context, bracelet),
          const SizedBox(height: 16),

          // Bouton action
          _buildActionButton(context, bracelet),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // CARD STATUT BRACELET
  // ==========================================
  Widget _buildStatusCard(BuildContext context, BraceletModel bracelet) {
    final isConnected = bracelet.isConnected;
    final statusColor = isConnected ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.watch, size: 56, color: Colors.white),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            bracelet.patientName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'En ligne' : 'Hors ligne',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWhiteIndicator(
                _getBatteryIcon(bracelet.batteryLevel),
                '${bracelet.batteryLevel}%',
                'Batterie',
                _getBatteryColor(bracelet.batteryLevel),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildWhiteIndicator(
                Icons.location_on,
                bracelet.city ?? 'Inconnue',
                'Position',
                Colors.white,
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildWhiteIndicator(
                Icons.access_time,
                _formatLastUpdate(bracelet.lastUpdate),
                'Mise à jour',
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  NOUVEAU : CARD CARTE GÉOGRAPHIQUE
  // ==========================================

  Widget _buildMapCard(BuildContext context, BraceletModel bracelet) {
    //  On utilise bracelet.latitude et bracelet.longitude
    if (bracelet.latitude == null || bracelet.longitude == null || (bracelet.latitude == 0.0 && bracelet.longitude == 0.0)) {
      return const SizedBox.shrink(); // On ne montre rien si on n'a pas les coordonnées
    }

    final latLng = LatLng(bracelet.latitude!, bracelet.longitude!);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.map, color: Colors.green[600], size: 20),
                const SizedBox(width: 8),
                const Text('Localisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(bracelet.city ?? 'Inconnue', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 180, // Hauteur de la carte
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: latLng,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Désactive la rotation
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.falldetection.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: latLng,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  CARD DOSSIER MÉDICAL
  // ==========================================
  Widget _buildMedicalCard(BuildContext context, BraceletModel bracelet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_information, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text('Dossier Médical', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          _buildMedicalRow(Icons.person, 'Patient',
              '${bracelet.patientName}${bracelet.patientAge != null ? ' · ${bracelet.patientAge} ans' : ''}'),
          if (bracelet.city != null)
            _buildMedicalRow(Icons.location_city, 'Ville', bracelet.city!),
          if (bracelet.bloodType != null)
            _buildMedicalRow(Icons.water_drop, 'Groupe sanguin', bracelet.bloodType!),
          if (bracelet.medicalConditions != null && bracelet.medicalConditions!.isNotEmpty)
            _buildMedicalRow(Icons.local_hospital, 'Pathologies', bracelet.medicalConditions!),
          if (bracelet.medications != null && bracelet.medications!.isNotEmpty)
            _buildMedicalRow(Icons.medication, 'Médicaments', bracelet.medications!),
          if (bracelet.medicalConditions == null && bracelet.medications == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Aucune donnée médicale renseignée',
                  style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  // ==========================================
  //  CARD INFOS TECHNIQUES
  // ==========================================
  Widget _buildInfoCard(BuildContext context, BraceletModel bracelet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_remote, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              const Text('Infos Bracelet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Batterie', '${bracelet.batteryLevel}% — ${bracelet.batteryStatus}',
              _getBatteryColor(bracelet.batteryLevel)),
          _buildInfoRow('Statut', bracelet.connectionStatus,
              bracelet.isConnected ? Colors.green : Colors.red),
          _buildInfoRow('Dernière activité', _formatLastUpdateFull(bracelet.lastUpdate), Colors.grey),
          if (bracelet.firmwareVersion != null)
            _buildInfoRow('Firmware', bracelet.firmwareVersion!, Colors.blue),
        ],
      ),
    );
  }

  // ==========================================
  //  BOUTON ACTION
  // ==========================================
  Widget _buildActionButton(BuildContext context, BraceletModel bracelet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditPatientProfileScreen(bracelet: bracelet)),
        ),
        icon: const Icon(Icons.edit_note),
        label: const Text('Modifier le dossier médical',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
    );
  }

  // ==========================================
  //  WIDGETS UTILITAIRES
  // ==========================================
  Widget _buildWhiteIndicator(IconData icon, String value, String label, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildMedicalRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  HELPERS
  // ==========================================
  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  IconData _getBatteryIcon(int level) {
    if (level > 80) return Icons.battery_full;
    if (level > 50) return Icons.battery_4_bar;
    if (level > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  String _formatLastUpdate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  String _formatLastUpdateFull(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }
}
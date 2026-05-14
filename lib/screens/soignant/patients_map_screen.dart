import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../models/user_model.dart';
import 'dart:async';
class PatientsMapScreen extends StatefulWidget {
  final UserModel user;

  const PatientsMapScreen({super.key, required this.user});

  @override
  State<PatientsMapScreen> createState() => _PatientsMapScreenState();
}

class _PatientsMapScreenState extends State<PatientsMapScreen> {
  static const Color primaryColor = Color(0xFF00695C);
  static const Color dangerColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color purpleColor = Color(0xFF5E35B1);

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  final FocusNode _searchFocusNode = FocusNode();
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value);
    return null;
  }

  latlng.LatLng _calculateCenter(List<latlng.LatLng> points) {
    if (points.isEmpty) {
      return const latlng.LatLng(35.5047, 11.0622); // Mahdia par défaut
    }

    double totalLat = 0;
    double totalLon = 0;

    for (final point in points) {
      totalLat += point.latitude;
      totalLon += point.longitude;
    }

    return latlng.LatLng(
      totalLat / points.length,
      totalLon / points.length,
    );
  }

  Color _getBatteryColor(int level) {
    if (level <= 15) return dangerColor;
    if (level <= 30) return warningColor;
    return Colors.green;
  }

  void _showPatientMapDetails(Map<String, dynamic> patient) {
    final location = patient['location'] as Map<String, dynamic>? ?? {};
    final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
    final isConnected = patient['isConnected'] == true;
    final batteryLevel = (patient['batteryLevel'] as int?) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.elderly,
                    color: primaryColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['patientName'] ?? 'Patient inconnu',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CIN : ${patient['cin'] ?? 'Non renseignée'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.withOpacity(0.1)
                        : dangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isConnected ? 'Actif' : 'Hors-ligne',
                    style: TextStyle(
                      color: isConnected ? Colors.green : dangerColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _detailRow(
              Icons.location_on_outlined,
              'Ville',
              location['city'] ?? 'Inconnue',
              primaryColor,
            ),
            const Divider(height: 22),
            _detailRow(
              Icons.my_location,
              'Coordonnées',
              '${location['lat'] ?? '?'} , ${location['lon'] ?? '?'}',
              Colors.blue,
            ),
            const Divider(height: 22),
            _detailRow(
              Icons.cake_outlined,
              'Âge',
              '${medical['age'] ?? '?'} ans',
              Colors.deepPurple,
            ),
            const Divider(height: 22),
            _detailRow(
              Icons.battery_charging_full,
              'Batterie',
              '$batteryLevel%',
              _getBatteryColor(batteryLevel),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: const Text(
          'Carte des patients',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bracelets')
            .where('ownerId', isEqualTo: widget.user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState(
              Icons.person_off_outlined,
              'Aucun patient affecté',
              'Aucun patient n’est lié à votre compte.',
            );
          }

          final allPatients = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'];

            if (location is! Map) return false;

            final lat = _toDouble(location['lat']);
            final lon = _toDouble(location['lon'] ?? location['lng']);

            if (lat == null || lon == null) return false;
            if (lat == 0.0 && lon == 0.0) return false;

            return true;
          }).toList();

          final filteredPatients = allPatients.where((doc) {
            if (_searchQuery.isEmpty) return true;

            final data = doc.data() as Map<String, dynamic>;
            final patientName =
            (data['patientName'] ?? '').toString().toLowerCase();
            final cin = (data['cin'] ?? '').toString().toLowerCase();
            final city = ((data['location'] as Map?)?['city'] ?? '')
                .toString()
                .toLowerCase();

            return patientName.contains(_searchQuery) ||
                cin.contains(_searchQuery) ||
                city.contains(_searchQuery);
          }).toList();

          if (allPatients.isEmpty) {
            return _emptyState(
              Icons.location_off_outlined,
              'Positions indisponibles',
              'Les patients existent, mais aucune coordonnée GPS valide n’est disponible.',
            );
          }

          final points = filteredPatients.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'] as Map;
            final lat = _toDouble(location['lat'])!;
            final lon = _toDouble(location['lon'] ?? location['lng'])!;
            return latlng.LatLng(lat, lon);
          }).toList();

          final center = _calculateCenter(points.isEmpty
              ? allPatients.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'] as Map;
            final lat = _toDouble(location['lat'])!;
            final lon = _toDouble(location['lon'] ?? location['lng'])!;
            return latlng.LatLng(lat, lon);
          }).toList()
              : points);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                color: primaryColor,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: (value) {
                        _searchDebounce?.cancel();

                        _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                          if (!mounted) return;

                          setState(() {
                            _searchQuery = value.trim().toLowerCase();
                          });

                          _searchFocusNode.requestFocus();
                        });
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, CIN ou ville...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: primaryColor,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        _counterChip(
                          '${filteredPatients.length}',
                          'affichés',
                          Colors.white,
                        ),
                        const SizedBox(width: 8),
                        _counterChip(
                          '${allPatients.length}',
                          'avec GPS',
                          Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (filteredPatients.isEmpty)
                Expanded(
                  child: _emptyState(
                    Icons.search_off,
                    'Aucun résultat',
                    'Aucun patient ne correspond à votre recherche.',
                  ),
                )
              else
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12.5,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.falldetect',
                      ),
                      MarkerLayer(
                        markers: filteredPatients.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final location = data['location'] as Map;

                          final lat = _toDouble(location['lat'])!;
                          final lon = _toDouble(location['lon'] ?? location['lng'])!;

                          final patientName = data['patientName'] ?? 'Patient';
                          final isConnected = data['isConnected'] == true;

                          return Marker(
                            point: latlng.LatLng(lat, lon),
                            width: 140,
                            height: 78,
                            child: GestureDetector(
                              onTap: () {
                                _showPatientMapDetails({
                                  ...data,
                                  'id': doc.id,
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 7,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      patientName.toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isConnected
                                          ? Colors.green
                                          : dangerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.elderly,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _counterChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
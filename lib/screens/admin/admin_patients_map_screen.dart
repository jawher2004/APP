import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class AdminPatientsMapScreen extends StatefulWidget {
  const AdminPatientsMapScreen({super.key});

  @override
  State<AdminPatientsMapScreen> createState() => _AdminPatientsMapScreenState();
}

class _AdminPatientsMapScreenState extends State<AdminPatientsMapScreen> {
  static const Color primaryColor = Color(0xFF004D40);
  static const Color dangerColor = Color(0xFFA32D2D);
  static const Color warningColor = Color(0xFFE65100);

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounce;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value);
    return null;
  }

  latlng.LatLng _calculateCenter(List<latlng.LatLng> points) {
    if (points.isEmpty) {
      return const latlng.LatLng(36.8065, 10.1815); // Tunis par défaut
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

  Color _batteryColor(int level) {
    if (level <= 15) return dangerColor;
    if (level <= 30) return warningColor;
    return Colors.green;
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    final location = patient['location'] as Map<String, dynamic>? ?? {};
    final medical = patient['medicalRecord'] as Map<String, dynamic>? ?? {};
    final isConnected = patient['isConnected'] == true;
    final batteryLevel = (patient['batteryLevel'] as int?) ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                  _statusBadge(
                    isConnected ? 'Connecté' : 'Hors-ligne',
                    isConnected ? Colors.green : dangerColor,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _detailRow(
                Icons.local_hospital_outlined,
                'Soignant',
                patient['ownerName'] ?? 'Aucun soignant',
                Colors.deepPurple,
              ),
              const Divider(height: 22),

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
                Colors.orange,
              ),
              const Divider(height: 22),

              _detailRow(
                Icons.battery_charging_full,
                'Batterie',
                '$batteryLevel%',
                _batteryColor(batteryLevel),
              ),
            ],
          ),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchQueryNotifier.dispose();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
  Widget _buildSearchHeader(int totalWithGps, int totalPatients) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      color: primaryColor,
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            onChanged: (value) {
              _searchDebounce?.cancel();

              _searchDebounce = Timer(
                const Duration(milliseconds: 350),
                    () {
                  _searchQueryNotifier.value = value.trim().toLowerCase();
                },
              );
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher patient, CIN, soignant ou ville...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: primaryColor,
                size: 20,
              ),
              suffixIcon: ValueListenableBuilder<String>(
                valueListenable: _searchQueryNotifier,
                builder: (context, query, _) {
                  if (_searchCtrl.text.isEmpty) return const SizedBox.shrink();

                  return IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchCtrl.clear();
                      _searchQueryNotifier.value = '';
                      _searchFocusNode.requestFocus();
                    },
                  );
                },
              ),
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

          ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, query, _) {
              return Row(
                children: [
                  _counterChip(
                    query.isEmpty ? '$totalWithGps' : 'Recherche',
                    query.isEmpty ? 'affichés' : 'active',
                  ),
                  const SizedBox(width: 8),
                  _counterChip('$totalWithGps', 'avec GPS'),
                  const SizedBox(width: 8),
                  _counterChip('$totalPatients', 'total'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: AppBar(
        title: const Text(
          'Carte globale des patients',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bracelets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState(
              Icons.person_off_outlined,
              'Aucun patient',
              'Aucun patient n’existe encore dans le système.',
            );
          }

          final allPatientsWithGps = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'];

            if (location is! Map) return false;

            final lat = _toDouble(location['lat']);
            final lon = _toDouble(location['lon'] ?? location['lng']);

            if (lat == null || lon == null) return false;
            if (lat == 0.0 && lon == 0.0) return false;

            return true;
          }).toList();

          if (allPatientsWithGps.isEmpty) {
            return _emptyState(
              Icons.location_off_outlined,
              'Positions indisponibles',
              'Les patients existent, mais aucune coordonnée GPS valide n’est disponible.',
            );
          }

          return Column(
            children: [
              _buildSearchHeader(
                allPatientsWithGps.length,
                snapshot.data!.docs.length,
              ),

              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, searchQuery, _) {
                    final filteredPatients = allPatientsWithGps.where((doc) {
                      if (searchQuery.isEmpty) return true;

                      final data = doc.data() as Map<String, dynamic>;
                      final location = data['location'] as Map?;

                      final patientName =
                      (data['patientName'] ?? '').toString().toLowerCase();
                      final cin = (data['cin'] ?? '').toString().toLowerCase();
                      final ownerName =
                      (data['ownerName'] ?? '').toString().toLowerCase();
                      final city =
                      (location?['city'] ?? '').toString().toLowerCase();

                      return patientName.contains(searchQuery) ||
                          cin.contains(searchQuery) ||
                          ownerName.contains(searchQuery) ||
                          city.contains(searchQuery);
                    }).toList();

                    if (filteredPatients.isEmpty) {
                      return _emptyState(
                        Icons.search_off,
                        'Aucun résultat',
                        'Aucun patient ne correspond à votre recherche.',
                      );
                    }

                    final points = filteredPatients.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final location = data['location'] as Map;

                      return latlng.LatLng(
                        _toDouble(location['lat'])!,
                        _toDouble(location['lon'] ?? location['lng'])!,
                      );
                    }).toList();

                    final center = _calculateCenter(points);

                    return FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 7,
                        minZoom: 4,
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
                            final lon =
                            _toDouble(location['lon'] ?? location['lng'])!;

                            final patientName = data['patientName'] ?? 'Patient';
                            final ownerName = data['ownerName'] ?? 'Non affecté';
                            final isConnected = data['isConnected'] == true;

                            return Marker(
                              point: latlng.LatLng(lat, lon),
                              width: 150,
                              height: 82,
                              child: GestureDetector(
                                onTap: () {
                                  _showPatientDetails({
                                    ...data,
                                    'id': doc.id,
                                  });
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      constraints:
                                      const BoxConstraints(maxWidth: 145),
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
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            patientName.toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ownerName.toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                        isConnected ? Colors.green : dangerColor,
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
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _counterChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
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
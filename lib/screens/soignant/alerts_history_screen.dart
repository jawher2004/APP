import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/alert_model.dart';
import 'alert_details_screen.dart';

class AlertsHistoryScreen extends StatefulWidget {
  final UserModel user;

  const AlertsHistoryScreen({super.key, required this.user});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  String _filterType = 'ALL'; // ALL, FALL, WARNING
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Alertes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres actifs
          if (_filterType != 'ALL' || _startDate != null || _endDate != null)
            _buildActiveFilters(),

          // Liste des alertes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getAlertsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Erreur Firestore: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Erreur de chargement',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune alerte',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Les alertes s\'afficheront ici',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                //  Tri manuel côté client (pas besoin d'index)
                final alerts = snapshot.data!.docs
                    .map((doc) => AlertModel.fromFirestore(doc))
                    .where(_applyFilters)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun résultat',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Réinitialiser les filtres'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    return _buildAlertCard(alerts[index], index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  //  Requête simple sans orderBy (pas besoin d'index composite)
  Stream<QuerySnapshot> _getAlertsStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('ownerId', isEqualTo: widget.user.uid)
        .snapshots();
  }

  bool _applyFilters(AlertModel alert) {
    // Filtre par type
    if (_filterType != 'ALL' && alert.type != _filterType) {
      return false;
    }

    // Filtre par date
    if (_startDate != null && alert.createdAt.isBefore(_startDate!)) {
      return false;
    }

    if (_endDate != null && alert.createdAt.isAfter(_endDate!)) {
      return false;
    }

    return true;
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtres actifs:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_filterType != 'ALL')
                Chip(
                  label: Text('Type: $_filterType'),
                  onDeleted: () => setState(() => _filterType = 'ALL'),
                ),
              if (_startDate != null)
                Chip(
                  label: Text('Du: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'),
                  onDeleted: () => setState(() => _startDate = null),
                ),
              if (_endDate != null)
                Chip(
                  label: Text('Au: ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                  onDeleted: () => setState(() => _endDate = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertModel alert, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _getAlertColor(alert).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () => _showAlertDetails(alert),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getAlertColor(alert).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getAlertIcon(alert),
                    color: _getAlertColor(alert),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getAlertTitle(alert),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getProbabilityColor(alert.probability)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              alert.probabilityPercent,
                              style: TextStyle(
                                color: _getProbabilityColor(alert.probability),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.formattedDate,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Patient: ${alert.patientName}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Flèche
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

   void _showAlertDetails(AlertModel alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlertDetailsScreen(alert: alert),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer les alertes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type
              const Text('Type d\'alerte', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Toutes'),
                    selected: _filterType == 'ALL',
                    onSelected: (selected) {
                      setState(() => _filterType = 'ALL');
                      Navigator.pop(context);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Chutes'),
                    selected: _filterType == 'FALL',
                    onSelected: (selected) {
                      setState(() => _filterType = 'FALL');
                      Navigator.pop(context);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Alertes'),
                    selected: _filterType == 'WARNING',
                    onSelected: (selected) {
                      setState(() => _filterType = 'WARNING');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dates
              const Text('Période', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                title: Text(_startDate == null
                    ? 'Date de début'
                    : DateFormat('dd/MM/yyyy').format(_startDate!)),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
              ListTile(
                title: Text(_endDate == null
                    ? 'Date de fin'
                    : DateFormat('dd/MM/yyyy').format(_endDate!)),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Réinitialiser'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filterType = 'ALL';
      _startDate = null;
      _endDate = null;
    });
  }

  Color _getAlertColor(AlertModel alert) {
    if (alert.type == 'FALL') return Colors.red;
    return Colors.orange;
  }

  IconData _getAlertIcon(AlertModel alert) {
    if (alert.type == 'FALL') return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  String _getAlertTitle(AlertModel alert) {
    if (alert.type == 'FALL') return 'Chute détectée';
    return 'Alerte';
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 0.8) return Colors.red;
    if (probability >= 0.5) return Colors.orange;
    return Colors.yellow[700]!;
  }
}
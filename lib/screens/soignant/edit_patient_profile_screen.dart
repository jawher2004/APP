import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bracelet_model.dart';

class EditPatientProfileScreen extends StatefulWidget {
  final BraceletModel bracelet;
  const EditPatientProfileScreen({super.key, required this.bracelet});

  @override
  State<EditPatientProfileScreen> createState() => _EditPatientProfileScreenState();
}

class _EditPatientProfileScreenState extends State<EditPatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ageController;
  late TextEditingController _conditionsController;
  late TextEditingController _medicationsController;
  late TextEditingController _bloodTypeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.bracelet.patientAge?.toString() ?? '');
    _conditionsController = TextEditingController(text: widget.bracelet.medicalConditions ?? '');
    _medicationsController = TextEditingController(text: widget.bracelet.medications ?? '');
    _bloodTypeController = TextEditingController(text: widget.bracelet.bloodType ?? '');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('bracelets')
          .doc(widget.bracelet.id)
          .update({
        'medicalRecord': {
          'age': int.tryParse(_ageController.text) ?? 0,
          'conditions': _conditionsController.text.trim(),
          'medications': _medicationsController.text.trim(),
          'bloodType': _bloodTypeController.text.trim(),
        }
        // ✅ location supprimée — mise à jour automatique via IP du bracelet
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dossier médical mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text('Dossier — ${widget.bracelet.patientName}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info position automatique
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position détectée automatiquement via le bracelet'
                            '${widget.bracelet.city != null ? ' · ${widget.bracelet.city}' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section médicale
              Row(
                children: [
                  Icon(Icons.medical_information,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Dossier Médical',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // Âge + Groupe sanguin
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Âge',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bloodTypeController,
                      decoration: InputDecoration(
                        labelText: 'Groupe sanguin',
                        hintText: 'ex: O+',
                        prefixIcon: const Icon(Icons.water_drop_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pathologies
              TextFormField(
                controller: _conditionsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Antécédents médicaux',
                  hintText: 'Ex: Diabète type 2, Hypertension...',
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Médicaments
              TextFormField(
                controller: _medicationsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Médicaments en cours',
                  hintText: 'Ex: Aspirine, Insuline...',
                  prefixIcon: const Icon(Icons.medication_outlined),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 32),

              // Bouton sauvegarder
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isLoading ? 'Enregistrement...' : 'Enregistrer le dossier',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }
}
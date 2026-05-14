import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPatientProfileScreen extends StatefulWidget {
  final Map<String, dynamic> bracelet;

  const EditPatientProfileScreen({super.key, required this.bracelet});

  @override
  State<EditPatientProfileScreen> createState() => _EditPatientProfileScreenState();
}

class _EditPatientProfileScreenState extends State<EditPatientProfileScreen> {
  static const Color primaryColor = Color(0xFF1565C0); // Bleu Médical
  static const Color dangerColor = Color(0xFFA32D2D);

  late TextEditingController _ageController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _conditionsController;
  late TextEditingController _medicationsController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final medical = widget.bracelet['medicalRecord'] as Map<String, dynamic>? ?? {};

    _ageController = TextEditingController(text: medical['age']?.toString() ?? '');
    _bloodTypeController = TextEditingController(text: medical['bloodType'] ?? '');
    _conditionsController = TextEditingController(text: medical['conditions'] ?? '');
    _medicationsController = TextEditingController(text: medical['medications'] ?? '');
  }

  @override
  void dispose() {
    _ageController.dispose();
    _bloodTypeController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final braceletId = widget.bracelet['braceletId'] ?? widget.bracelet['id'];

      await FirebaseFirestore.instance.collection('bracelets').doc(braceletId).update({
        'medicalRecord': {
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'bloodType': _bloodTypeController.text.trim(),
          'conditions': _conditionsController.text.trim(),
          'medications': _medicationsController.text.trim(),
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Dossier médical mis à jour avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e'), backgroundColor: dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName = widget.bracelet['patientName'] ?? 'Sujet Inconnu';
    final cinDisplay = widget.bracelet['cin'] ?? 'Non renseignée';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mise à jour du dossier', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 EN-TÊTE PATIENT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.elderly, color: primaryColor, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('CIN : $cinDisplay', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Informations Biométriques', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ageController,
                    label: 'Âge du patient',
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _bloodTypeController,
                    label: 'Groupe Sanguin',
                    icon: Icons.bloodtype,
                    hint: 'Ex: A+, O-',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Dossier Clinique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _conditionsController,
              label: 'Antécédents & Pathologies',
              icon: Icons.history_edu,
              maxLines: 4,
              hint: 'Listez les pathologies majeures (Ex: Diabète type 2, Hypertension, Ostéoporose...)',
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _medicationsController,
              label: 'Traitements en cours',
              icon: Icons.medication,
              maxLines: 4,
              hint: 'Listez les médicaments actuels (Ex: Insuline rapide, Amlor...)',
            ),

            const SizedBox(height: 32),

            // BOUTON SAUVEGARDER
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save),
                label: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer les modifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: maxLines == 1 ? Icon(icon, color: primaryColor) : Padding(padding: const EdgeInsets.only(bottom: 50), child: Icon(icon, color: primaryColor)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
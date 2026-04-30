import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;
  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  // 🌟 NOUVEAU : Variable pour savoir si c'est une connexion Google
  bool _isGoogleSignIn = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkLoginProvider(); // 🌟 Vérification au chargement
  }

  // 🌟 NOUVEAU : Fonction qui vérifie les fournisseurs de connexion
  void _checkLoginProvider() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (var providerProfile in user.providerData) {
        if (providerProfile.providerId == 'google.com') {
          setState(() {
            _isGoogleSignIn = true;
          });
          break;
        }
      }
    }
  }

  Future<void> _loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    if (doc.exists) {
      _nameCtrl.text = doc.data()?['name'] ?? widget.user.name;
      _phoneCtrl.text = doc.data()?['phone'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Le nom ne peut pas être vide', Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      _showSnack('Profil mis à jour ✅', Colors.green);
    } catch (e) {
      _showSnack('Erreur : $e', Colors.red);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _changePassword() async {
    if (_currentPassCtrl.text.isEmpty || _newPassCtrl.text.isEmpty) {
      _showSnack('Remplis les deux champs', Colors.orange);
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      _showSnack('Mot de passe trop court (6 min)', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassCtrl.text);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _showSnack('Mot de passe changé ✅', Colors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnack('Mot de passe actuel incorrect', Colors.red);
      } else {
        _showSnack('Erreur : ${e.message}', Colors.red);
      }
    }
    setState(() => _isLoading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informations personnelles
            _buildCard(
              title: 'Informations personnelles',
              icon: Icons.person_outline,
              child: Column(
                children: [
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Nom complet',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Numéro de téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Sauvegarder'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🌟 AFFICHAGE CONDITIONNEL DE LA SÉCURITÉ
            if (_isGoogleSignIn)
              _buildCard(
                title: 'Sécurité du compte',
                icon: Icons.security,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.g_mobiledata, size: 40, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Vous êtes connecté via Google. Votre mot de passe est géré de manière sécurisée par Google.",
                          style: TextStyle(color: Colors.black87, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildCard(
                title: 'Sécurité',
                icon: Icons.lock_outline,
                child: Column(
                  children: [
                    _buildField(
                      controller: _currentPassCtrl,
                      label: 'Mot de passe actuel',
                      icon: Icons.lock_outline,
                      obscure: _obscureCurrent,
                      onToggleObscure: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _newPassCtrl,
                      label: 'Nouveau mot de passe',
                      icon: Icons.lock_reset_outlined,
                      obscure: _obscureNew,
                      onToggleObscure: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePassword,
                        icon: const Icon(Icons.key),
                        label: const Text('Changer le mot de passe'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onToggleObscure != null
            ? IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggleObscure,
        )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }
}
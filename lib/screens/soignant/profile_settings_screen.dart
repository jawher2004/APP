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
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color dangerColor = Color(0xFFA32D2D);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57C00);

  final _nameCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isGoogleSignIn = false;

  String _role = 'Soignant';

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.user.email;
    _loadProfile();
    _checkLoginProvider();
  }

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
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        _nameCtrl.text = data['name'] ?? widget.user.name;
        _cinCtrl.text = data['cin'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _emailCtrl.text = data['email'] ?? widget.user.email;
        _role = data['role'] ?? 'soignant';
      } else {
        _nameCtrl.text = widget.user.name;
        _emailCtrl.text = widget.user.email;
      }
    } catch (e) {
      _showSnack('Erreur de chargement : $e', dangerColor);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final cin = _cinCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Le nom ne peut pas être vide', dangerColor);
      return;
    }

    if (cin.isEmpty) {
      _showSnack('La CIN du soignant est obligatoire', warningColor);
      return;
    }

    if (cin.length < 6) {
      _showSnack('La CIN semble trop courte', warningColor);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'name': name,
        'cin': cin,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnack('Profil soignant mis à jour ✅', successColor);
    } catch (e) {
      _showSnack('Erreur : $e', dangerColor);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPassCtrl.text.isEmpty || _newPassCtrl.text.isEmpty) {
      _showSnack('Remplissez les deux champs', warningColor);
      return;
    }

    if (_newPassCtrl.text.length < 6) {
      _showSnack('Nouveau mot de passe trop court (6 caractères min.)', warningColor);
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

      _showSnack('Mot de passe mis à jour de manière sécurisée ✅', successColor);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnack('Le mot de passe actuel est incorrect.', dangerColor);
      } else {
        _showSnack('Erreur de sécurité : ${e.message}', dangerColor);
      }
    } catch (e) {
      _showSnack('Erreur : $e', dangerColor);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Gestion du profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInfoCard(),
            const SizedBox(height: 24),
            _buildProfessionalInfoCard(),
            const SizedBox(height: 24),
            _buildSecurityCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final hasCin = _cinCtrl.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircleAvatar(
              radius: 42,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.medical_information,
                size: 42,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dr. ${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : widget.user.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSmallBadge(
                icon: Icons.verified_user_outlined,
                text: _role.toUpperCase(),
                color: primaryColor,
              ),
              _buildSmallBadge(
                icon: Icons.badge_outlined,
                text: hasCin ? 'CIN : ${_cinCtrl.text}' : 'CIN non renseignée',
                color: hasCin ? successColor : warningColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _emailCtrl.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _buildCard(
      title: 'Coordonnées du soignant',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _buildField(
            controller: _nameCtrl,
            label: 'Nom complet',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _cinCtrl,
            label: 'CIN du soignant',
            icon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _phoneCtrl,
            label: 'Numéro d’astreinte',
            icon: Icons.phone_android,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _emailCtrl,
            label: 'Adresse email',
            icon: Icons.email_outlined,
            enabled: false,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.save),
              label: const Text(
                'Sauvegarder le profil',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return _buildCard(
      title: 'Informations professionnelles',
      icon: Icons.local_hospital_outlined,
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Rôle',
            value: _role == 'soignant' ? 'Soignant médical' : _role,
            color: primaryColor,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.fingerprint,
            label: 'Identifiant système',
            value: widget.user.uid,
            color: Colors.deepPurple,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.verified_outlined,
            label: 'Statut du compte',
            value: 'Compte actif',
            color: successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    if (_isGoogleSignIn) {
      return _buildCard(
        title: 'Sécurité d’accès',
        icon: Icons.security,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.g_mobiledata, size: 48, color: Colors.green),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Authentification sécurisée par Google. Aucune modification de mot de passe n'est requise.",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCard(
      title: 'Changer le mot de passe',
      icon: Icons.lock_outline,
      child: Column(
        children: [
          _buildField(
            controller: _currentPassCtrl,
            label: 'Mot de passe actuel',
            icon: Icons.lock_open,
            obscure: _obscureCurrent,
            onToggleObscure: () {
              setState(() => _obscureCurrent = !_obscureCurrent);
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _newPassCtrl,
            label: 'Nouveau mot de passe sécurisé',
            icon: Icons.lock_reset_outlined,
            obscure: _obscureNew,
            onToggleObscure: () {
              setState(() => _obscureNew = !_obscureNew);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.shield_outlined),
              label: const Text(
                'Mettre à jour la sécurité',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    bool enabled = true,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF5F7FA) : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: onToggleObscure,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cinCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }
}
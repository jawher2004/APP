import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fall_detection/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'mqtt_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Connexion Email/Password
  Future<UserModel?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return await getUserData(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Inscription Email/Password
  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = UserModel(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: role,
        braceletId: null,
        patientName: null,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(user.toFirestore());

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  //  Connexion avec Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Déclencher le flux d'authentification Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // L'utilisateur a annulé
        return null;
      }

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Vérifier que les tokens existent
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Erreur lors de la récupération des tokens Google';
      }

      // Créer les credentials Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      // Se connecter à Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user!;

      // Vérifier si l'utilisateur existe déjà dans Firestore
      final existingUser = await getUserData(firebaseUser.uid);

      if (existingUser != null) {
        // Utilisateur existant
        return existingUser;
      }

      // Nouvel utilisateur : créer le profil avec rôle soignant par défaut
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email!,
        name: firebaseUser.displayName ?? 'Utilisateur',
        role: UserRole.soignant, // Par défaut
        braceletId: null,
        patientName: null,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toFirestore());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Erreur Google Sign-In: $e');
      throw 'Erreur lors de la connexion avec Google. Veuillez réessayer.';
    }
  }

  // Récupérer les données utilisateur
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      throw 'Erreur lors de la récupération des données utilisateur';
    }
  }

  // Déconnexion

  Future<void> signOut() async {
    //  Déconnecter MQTT AVANT Firebase Auth
    MqttService().disconnect();
    print('[AUTH] MQTT déconnecté');

    // Nettoyer notifications
    await NotificationService().clearNotifications();
    print('[AUTH] Notifications nettoyées');

    // Déconnecter Firebase
    await FirebaseAuth.instance.signOut();
    print('[AUTH] Déconnexion complète');
  }

  // Gestion des erreurs
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun utilisateur trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'invalid-email':
        return 'Email invalide';
      case 'invalid-credential':
        return 'Identifiants invalides';
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec cet email';
      default:
        return 'Erreur d\'authentification: ${e.message}';
    }
  }
}

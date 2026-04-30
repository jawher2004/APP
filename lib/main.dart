import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/mqtt_service.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/soignant/soignant_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'models/user_model.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[BACKGROUND] Notification recue: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final NotificationService _notificationService = NotificationService();
  final MqttService _mqttService = MqttService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      print('========================================');
      print('🔐 Utilisateur connecté: ${currentUser.uid}');
      print('========================================');

      // Initialiser notifications FCM seulement
      await _notificationService.initialize();
      print('✅ FCM initialisé');

      // NE PAS initialiser MQTT ici
      // Le login_screen s'en charge après la connexion
      print('========================================');
    } else {
      print('⚠️ Aucun utilisateur connecté au démarrage');
    }
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detection de Chute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Chargement...'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<UserModel?>(
              future: _authService.getUserData(snapshot.data!.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userSnapshot.hasData && userSnapshot.data != null) {
                  final user = userSnapshot.data!;

                  if (user.role == UserRole.soignant) {
                    return SoignantDashboard(user: user);
                  } else if (user.role == UserRole.superAdmin) {
                    return AdminDashboard(user: user);
                  }
                }

                return const LoginScreen();
              },
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
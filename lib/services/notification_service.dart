import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  //  SUPPRIMÉ : Ne plus stocker _currentUserId dans une variable
  // On va toujours le récupérer depuis FirebaseAuth

  // Initialiser les notifications
  Future<void> initialize() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      print('⚠️ Aucun utilisateur connecté, notifications désactivées');
      return;
    }

    print('🔔 Initialisation notifications pour user: ${currentUser.uid}');

    // Demander la permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notifications autorisées');
    } else {
      print('⚠️ Notifications refusées');
      return;
    }

    // Configurer les options foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configuration
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📱 Notification cliquée: ${response.payload}');
      },
    );

    await _createNotificationChannel();

    //  Configuration des listeners
    print('🎧 Configuration des listeners FCM...');

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    print(' Listeners FCM configurés');

    // Écouter le rafraîchissement du token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print(' Token FCM rafraîchi: ${newToken.substring(0, 20)}...');
      await _saveTokenToFirestore(newToken);
    });

    // Générer et sauvegarder le token
    await _forceTokenGeneration();
  }

  // Forcer la génération d'un token
  Future<void> _forceTokenGeneration() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      print(' Génération d\'un nouveau token FCM...');

      await _messaging.deleteToken();
      print(' Ancien token supprimé');

      await Future.delayed(const Duration(seconds: 1));

      String? newToken = await _messaging.getToken();

      if (newToken != null) {
        print(' Nouveau token généré: ${newToken.substring(0, 30)}...');
        await _saveTokenToFirestore(newToken);
      } else {
        print('❌ Impossible de générer un token FCM');
      }
    } catch (e) {
      print('❌ Erreur génération token: $e');
    }
  }

  // Sauvegarder le token dans Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print(' Impossible de sauvegarder token : Pas d\'utilisateur');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      print(' Token sauvegardé dans Firestore');
      print('   User: ${currentUser.uid}');
      print('   Token: ${token.substring(0, 30)}...');
    } catch (e) {
      print(' Erreur sauvegarde token: $e');
    }
  }

  // Méthode publique pour forcer la sauvegarde
  Future<void> saveTokenToFirestore(String userId) async {
    await _forceTokenGeneration();
  }

  // Créer le canal de notification Android
  Future<void> _createNotificationChannel() async {
    print(' Création du canal de notification Android...');

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'fall_detection_channel',
      'Alertes de Chute',
      description: 'Notifications pour les alertes de chute détectées',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      print(' Canal "fall_detection_channel" créé');
    }
  }

  //  CORRIGÉ : Gérer les notifications en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    //  Récupérer l'utilisateur actuel MAINTENANT (pas depuis une variable)
    final currentUser = _auth.currentUser;

    print('');
    print('════════════════════════════════════════');
    print(' NOTIFICATION REÇUE (FOREGROUND)');
    print('════════════════════════════════════════');
    print('Notification title: ${message.notification?.title}');
    print('Notification body: ${message.notification?.body}');
    print('Data: ${message.data}');
    print('Current User ID: ${currentUser?.uid ?? "NULL"}');
    print('════════════════════════════════════════');

    if (currentUser == null) {
      print(' Notification ignorée : Aucun utilisateur connecté');
      return;
    }

    final targetUserId = message.data['ownerId'] ?? message.data['soignantId'];

    if (targetUserId == null) {
      print('Notification ignorée : Pas de destinataire');
      return;
    }

    if (targetUserId != currentUser.uid) {
      print(' Notification ignorée : Destinataire [$targetUserId] ≠ User actuel [${currentUser.uid}]');
      return;
    }

    // Vérifier le rôle avant d'afficher
    _checkUserRoleAndShowNotification(message, currentUser.uid);
  }

  // Vérifier le rôle avant d'afficher
  Future<void> _checkUserRoleAndShowNotification(RemoteMessage message, String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print(' Utilisateur non trouvé');
        return;
      }

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;

      if (userRole == 'soignant') {
        print(' Affichage notification pour soignant: $userId');

        final title = message.data['title'] ??
            message.notification?.title ??
            'Nouvelle alerte';

        final body = message.data['body'] ??
            message.notification?.body ??
            'Vous avez une alerte';

        _showLocalNotification(
          title: title,
          body: body,
          payload: message.data.toString(),
        );
      } else {
        print('️ Notification ignorée : User est $userRole (pas soignant)');
      }

    } catch (e) {
      print(' Erreur vérification rôle: $e');
    }
  }

  // Gérer les notifications en background
  void _handleBackgroundMessage(RemoteMessage message) {
    final currentUser = _auth.currentUser;
    print(' Notification en background: ${message.data}');
    print('   User actuel: ${currentUser?.uid ?? "NULL"}');
  }

  // Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('');
    print(' Affichage notification locale:');
    print('   Title: $title');
    print('   Body: $body');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fall_detection_channel',
      'Alertes de Chute',
      channelDescription: 'Notifications pour les alertes de chute',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      print(' Notification affichée avec succès !');
      print('');
    } catch (e) {
      print(' Erreur affichage notification: $e');
      print('');
    }
  }

  // Test notification
  Future<void> showTestNotification(String patientName) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      print('Test notification ignorée : Aucun utilisateur connecté');
      return;
    }

    print(' Test notification pour: $patientName');

    await _showLocalNotification(
      title: ' TEST Chute Détectée !',
      body: 'Le patient $patientName a chuté. (TEST)',
      payload: 'TEST_FALL_ALERT',
    );
  }

  // Nettoyer lors de la déconnexion
  Future<void> clearNotifications() async {
    await _localNotifications.cancelAll();
    print(' Notifications nettoyées');
  }

  // Envoyer une notification à un soignant
  Future<void> sendNotificationToSoignant({
    required String soignantId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(soignantId)
          .get();

      final fcmToken = doc.data()?['fcmToken'];

      if (fcmToken == null) {
        print(' Pas de token FCM pour le soignant $soignantId');
        return;
      }

      final notificationData = {
        ...?data,
        'soignantId': soignantId,
        'ownerId': soignantId,
      };

      await FirebaseFirestore.instance.collection('notifications').add({
        'to': fcmToken,
        'title': title,
        'body': body,
        'data': notificationData,
        'soignantId': soignantId,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      print(' Notification ajoutée à la queue');
    } catch (e) {
      print(' Erreur: $e');
    }
  }
}
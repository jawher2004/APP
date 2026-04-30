import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'notification_service.dart';

class TestDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Créer un bracelet pour un soignant
  Future<void> createBraceletForSoignant({
    required String soignantId,
    required String soignantName,
    required String patientName,
  }) async {
    final braceletId = 'bracelet_$soignantId';

    // 1. Créer le bracelet
    await _firestore.collection('bracelets').doc(braceletId).set({
      'ownerId': soignantId,
      'ownerName': soignantName,
      'patientName': patientName,
      'batteryLevel': 85,
      'isConnected': true,
      'lastUpdate': FieldValue.serverTimestamp(),
      'firmwareVersion': 'v1.2.3',
    });

    // 2. Mettre à jour le soignant
    await _firestore.collection('users').doc(soignantId).update({
      'braceletId': braceletId,
      'patientName': patientName,
    });

    print('✅ Bracelet créé pour $soignantName (patient: $patientName)');
  }

  // Créer des alertes de test
  Future<void> createTestAlerts({
    required String braceletId,
    required String ownerId,
    required String patientName,
    required int count,
  }) async {
    final random = Random();

    for (int i = 0; i < count; i++) {
      final daysAgo = random.nextInt(30);
      final hoursAgo = random.nextInt(24);
      final timestamp = DateTime.now()
          .subtract(Duration(days: daysAgo, hours: hoursAgo));

      await _firestore.collection('alerts').add({
        'type': random.nextBool() ? 'FALL' : 'WARNING',
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'probability': 0.5 + (random.nextDouble() * 0.5),
        'braceletId': braceletId,
        'ownerId': ownerId,
        'patientName': patientName,
        'createdAt': Timestamp.fromDate(timestamp),
        'isRead': random.nextBool(),
      });
    }

    print('✅ $count alertes créées pour $patientName');
  }

  // Simuler une chute avec notification
  Future<void> simulateFall({
    required String braceletId,
    required String ownerId,
    required String patientName,
  }) async {
    // Créer l'alerte
    await _firestore.collection('alerts').add({
      'type': 'FALL',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'probability': 0.92,
      'braceletId': braceletId,
      'ownerId': ownerId,
      'patientName': patientName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    //  Envoyer une notification locale immédiate
    await _notificationService.showTestNotification(patientName);

    //  Envoyer une notification push (via Cloud Function)
    await _notificationService.sendNotificationToSoignant(
      soignantId: ownerId,
      title: '🚨 Chute Détectée !',
      body: 'Le patient $patientName a chuté. Probabilité: 92%',
      data: {
        'type': 'FALL',
        'patientName': patientName,
        'braceletId': braceletId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    print('✅ Chute simulée + notification envoyée pour $patientName');
  }

  // Mettre à jour la batterie
  Future<void> updateBatteryLevel(String braceletId, int level) async {
    await _firestore.collection('bracelets').doc(braceletId).update({
      'batteryLevel': level,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  // Toggle connexion
  Future<void> toggleConnection(String braceletId, bool isConnected) async {
    await _firestore.collection('bracelets').doc(braceletId).update({
      'isConnected': isConnected,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }
}
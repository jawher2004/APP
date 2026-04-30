import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class MqttService {
  static const String _broker = '95e99bcd3ac6404f88b4cad23cbebdd1.s1.eu.hivemq.cloud';
  static const int _port = 8883;
  static const String _username = 'fall_detection';
  static const String _password = 'FallDetect2026';

  static const String topicAlerts = 'fall_detection/alerts';
  static const String topicStatus = 'fall_detection/status';

  // Singleton
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _statusTimer;
  StreamSubscription? _mqttSubscription;
  bool _isInitializing = false;

  final StreamController<Map<String, dynamic>> _alertController =
  StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  final StreamController<Map<String, dynamic>> _statusController =
  StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  void _resetStatusTimer(String braceletId) {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 90), () async {
      print('[MQTT] ⏰ Timeout bracelet $braceletId');
      try {
        await _firestore.collection('bracelets').doc(braceletId).update({
          'isConnected': false,
          'lastUpdate': FieldValue.serverTimestamp(),
        });
        _statusController.add({
          'braceletId': braceletId,
          'status': 'offline',
          'isConnected': false,
        });
      } catch (e) {
        print('[MQTT] Erreur timeout: $e');
      }
    });
  }

  Future<void> initialize() async {
    if (_isInitializing) {
      print('[MQTT] ⚠️ Déjà en cours d\'initialisation');
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('[MQTT] ⚠️ Pas d\'utilisateur connecté');
      return;
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) {
      print('[MQTT] ⚠️ Utilisateur non trouvé dans Firestore');
      return;
    }

    final userRole = userDoc.data()!['role'] as String? ?? '';
    print('[MQTT] 📋 Rôle: "$userRole"');

    if (userRole != 'soignant' && userRole != 'Soignant') {
      print('[MQTT] ⚠️ Pas soignant, MQTT désactivé');
      return;
    }

    _isInitializing = true;

    if (_client != null) {
      print('[MQTT] 🧹 Nettoyage ancien client...');
      _mqttSubscription?.cancel();
      _mqttSubscription = null;
      try {
        _client!.disconnect();
      } catch (e) {
        // Ignorer
      }
      _client = null;
      _isConnected = false;
    }

    print('[MQTT] 🔔 Initialisation pour soignant: ${currentUser.uid}');

    final clientId = 'flutter_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient(_broker, clientId);
    _client!.port = _port;
    _client!.secure = true;
    _client!.onBadCertificate = (dynamic certificate) => true;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(_username, _password)
        .withWillTopic(topicStatus)
        .withWillMessage('{"status":"offline","userId":"${currentUser.uid}"}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      print('[MQTT] 🔌 Connexion à $_broker:$_port...');
      await _client!.connect();
    } catch (e) {
      print('[MQTT] ❌ ERREUR connexion: $e');
      _isConnected = false;
      _isInitializing = false;
      return;
    }

    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected = true;
      print('[MQTT] ✅ Connecté avec succès !');
      _subscribeToTopics();
    } else {
      print('[MQTT] ❌ Échec: ${_client!.connectionStatus}');
      _isConnected = false;
    }

    _isInitializing = false;
  }

  void _subscribeToTopics() {
    if (_client == null) return;

    // Annuler l'ancien listener pour éviter les doublons
    _mqttSubscription?.cancel();
    _mqttSubscription = null;

    print('[MQTT] 📡 Abonnement aux topics...');
    _client!.subscribe(topicAlerts, MqttQos.atLeastOnce);
    _client!.subscribe(topicStatus, MqttQos.atLeastOnce);
    print('[MQTT] ✅ Abonné à: $topicAlerts');
    print('[MQTT] ✅ Abonné à: $topicStatus');

    // Un seul listener
    _mqttSubscription = _client!.updates?.listen(_onMessage);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final data = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

      print('');
      print('[MQTT] ══════════════════════════════════════');
      print('[MQTT] 📩 Message reçu sur: $topic');
      print('[MQTT] ══════════════════════════════════════');

      try {
        final jsonData = json.decode(data) as Map<String, dynamic>;
        if (topic == topicAlerts) {
          _handleFallAlert(jsonData);
        } else if (topic == topicStatus) {
          _handleStatusUpdate(jsonData);
        }
      } catch (e) {
        print('[MQTT] ❌ Erreur parsing: $e');
      }
    }
  }

  Future<void> _handleFallAlert(Map<String, dynamic> data) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final braceletId = data['braceletId'] as String? ?? '';
    print('[MQTT] 🚨 Alerte chute: $braceletId');

    try {
      String ownerId = '';
      String patientName = 'Patient inconnu';

      final braceletDoc = await _firestore.collection('bracelets').doc(braceletId).get();
      if (braceletDoc.exists) {
        ownerId = braceletDoc.data()!['ownerId'] as String? ?? '';
        patientName = braceletDoc.data()!['patientName'] as String? ?? 'Patient inconnu';
      } else {
        final usersQuery = await _firestore.collection('users')
            .where('braceletId', isEqualTo: braceletId)
            .limit(1)
            .get();

        if (usersQuery.docs.isNotEmpty) {
          ownerId = usersQuery.docs.first.id;
          patientName = usersQuery.docs.first.data()['patientName'] as String? ?? 'Patient';

          await _firestore.collection('bracelets').doc(braceletId).set({
            'id': braceletId,
            'ownerId': ownerId,
            'ownerName': usersQuery.docs.first.data()['name'] ?? '',
            'patientName': patientName,
            'batteryLevel': data['batteryLevel'] ?? 100,
            'isConnected': true,
            'lastUpdate': FieldValue.serverTimestamp(),
            'firmwareVersion': '1.0.0',
          });
        } else if (braceletId.contains(currentUser.uid)) {
          ownerId = currentUser.uid;
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          patientName = userDoc.data()?['patientName'] as String? ?? 'Patient';
        } else {
          print('[MQTT] ❌ Aucun propriétaire trouvé');
          return;
        }
      }

      if (ownerId != currentUser.uid) {
        print('[MQTT] ⚠️ Pas pour cet utilisateur');
        return;
      }

      final probability = (data['probability'] as num?)?.toDouble() ?? 0.92;

      // Anti-doublon : vérifier si une alerte existe déjà dans les 30 dernières secondes
      final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final thirtySecondsAgo = nowTimestamp - 30;
      try {
        final recentAlerts = await _firestore
            .collection('alerts')
            .where('braceletId', isEqualTo: braceletId)
            .where('timestamp', isGreaterThan: thirtySecondsAgo)
            .limit(1)
            .get();

        if (recentAlerts.docs.isNotEmpty) {
          print('[MQTT] ⚠️ Alerte déjà créée dans les 30 dernières secondes, ignorée');
          return;
        }
      } catch (e) {
        print('[MQTT] ⚠️ Erreur vérification doublon: $e (on continue)');
      }

      final alertRef = await _firestore.collection('alerts').add({
        'type': 'FALL',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'probability': probability,
        'braceletId': braceletId,
        'ownerId': ownerId,
        'patientName': patientName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'source': 'MQTT_APP',
        'sensorData': {
          'accelX': data['accelX'],
          'accelY': data['accelY'],
          'accelZ': data['accelZ'],
          'gyroX': data['gyroX'],
          'gyroY': data['gyroY'],
          'gyroZ': data['gyroZ'],
          'totalAccel': data['totalAccel'],
          'temperature': data['temperature'],
        },
      });

      print('[MQTT] ✅ Alerte sauvegardée: ${alertRef.id}');

      print('[MQTT] 🔔 Notification...');
      await _notificationService.showTestNotification(patientName);

      _alertController.add({
        'alertId': alertRef.id,
        'patientName': patientName,
        'probability': probability,
        'braceletId': braceletId,
        'timestamp': DateTime.now().toIso8601String(),
        ...data,
      });

      print('[MQTT] ✅ Alerte traitée !');
    } catch (e) {
      print('[MQTT] ❌ Erreur: $e');
    }
  }

  Future<void> _handleStatusUpdate(Map<String, dynamic> data) async {
    final braceletId = data['braceletId'] as String? ?? '';
    if (braceletId.isEmpty) return;

    print('[MQTT] 📊 Statut: $braceletId');

    try {
      final braceletRef = _firestore.collection('bracelets').doc(braceletId);
      final braceletDoc = await braceletRef.get();

      if (braceletDoc.exists) {
        await braceletRef.update({
          'batteryLevel': data['batteryLevel'] ?? 0,
          'isConnected': data['isConnected'] ?? (data['status'] == 'online'),
          'lastUpdate': FieldValue.serverTimestamp(),
          'wifiRSSI': data['wifiRSSI'],
          'temperature': data['temperature'],
        });
        print('[MQTT] ✅ Statut mis à jour');
      } else {
        final currentUser = _auth.currentUser;
        if (currentUser != null && braceletId.contains(currentUser.uid)) {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          await braceletRef.set({
            'id': braceletId,
            'ownerId': currentUser.uid,
            'ownerName': userDoc.data()?['name'] ?? '',
            'patientName': userDoc.data()?['patientName'] ?? '',
            'batteryLevel': data['batteryLevel'] ?? 100,
            'isConnected': data['isConnected'] ?? true,
            'lastUpdate': FieldValue.serverTimestamp(),
            'firmwareVersion': '1.0.0',
          });
          print('[MQTT] ✅ Bracelet CRÉÉ');
        }
      }

      _resetStatusTimer(braceletId);
      _statusController.add(data);
    } catch (e) {
      print('[MQTT] ❌ Erreur: $e');
    }
  }

  void _onConnected() {
    _isConnected = true;
    print('[MQTT] ✅ Connecté !');
  }

  void _onDisconnected() {
    _isConnected = false;
    print('[MQTT] ⚠️ Déconnecté !');
  }

  void _onAutoReconnect() {
    print('[MQTT] 🔄 Reconnexion...');
  }

  void _onAutoReconnected() {
    _isConnected = true;
    print('[MQTT] ✅ Reconnecté !');
    Future.delayed(const Duration(seconds: 1), () {
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _subscribeToTopics();
      }
    });
  }

  void disconnect() {
    print('[MQTT] 🔌 Déconnexion...');
    _statusTimer?.cancel();
    _mqttSubscription?.cancel();
    _mqttSubscription = null;

    if (_client != null) {
      try {
        if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
          _client!.disconnect();
        }
      } catch (e) {
        print('[MQTT] Erreur déconnexion: $e');
      }
    }

    _client = null;
    _isConnected = false;
    _isInitializing = false;

    print('[MQTT] 🔌 Déconnexion propre');
  }

  void publish(String topic, Map<String, dynamic> data) {
    if (!_isConnected || _client == null) return;
    final payload = json.encode(data);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('[MQTT] 📤 Publié sur $topic');
  }

  void dispose() {
    disconnect();
  }
}
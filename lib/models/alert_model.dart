import 'package:cloud_firestore/cloud_firestore.dart';

// 🌤️ NOUVELLE CLASSE : WeatherData
class WeatherData {
  final int temperature;
  final int feelsLike;
  final int humidity;
  final String description;
  final String icon;
  final double windSpeed;
  final String city;
  final String country;
  final String riskLevel;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.city,
    required this.country,
    required this.riskLevel,
  });

  factory WeatherData.fromMap(Map<String, dynamic> map) {
    return WeatherData(
      temperature: (map['temperature'] ?? 0).toInt(),
      feelsLike: (map['feelsLike'] ?? 0).toInt(),
      humidity: (map['humidity'] ?? 0).toInt(),
      description: map['description'] ?? '',
      icon: map['icon'] ?? '',
      windSpeed: (map['windSpeed'] ?? 0).toDouble(),
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      riskLevel: map['riskLevel'] ?? 'normal',
    );
  }
}

class AlertModel {
  final String id;
  final String type;
  final int timestamp;
  final double probability;
  final String braceletId;
  final String ownerId;
  final String patientName;
  final DateTime createdAt;
  final bool isRead;

  // 🌤️ NOUVEAU CHAMP : weather
  final WeatherData? weather;
  final String? aiReport;

  AlertModel({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.probability,
    required this.braceletId,
    required this.ownerId,
    required this.patientName,
    required this.createdAt,
    this.isRead = false,
    this.weather,
    this.aiReport,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      type: data['type'] ?? 'UNKNOWN',
      timestamp: data['timestamp'] ?? 0,
      probability: (data['probability'] ?? 0.0).toDouble(),
      braceletId: data['braceletId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      patientName: data['patientName'] ?? 'Patient inconnu',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch((data['timestamp'] ?? 0) * 1000),
      isRead: data['isRead'] ?? false,
      // 👈 On parse la météo si elle existe
      weather: data['weather'] != null ? WeatherData.fromMap(data['weather']) : null,
      aiReport: data['aiReport'],
    );
  }

  String get formattedDate {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get probabilityPercent {
    return '${(probability * 100).toStringAsFixed(0)}%';
  }
}
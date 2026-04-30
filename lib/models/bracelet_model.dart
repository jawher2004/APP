import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BraceletModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String patientName;
  final int batteryLevel;
  final bool isConnected;
  final DateTime lastUpdate;
  final String? firmwareVersion;

  // 📍 NOUVEAU : Localisation pour la Météo
  final double? latitude;
  final double? longitude;
  final String? city;

  // 🏥 NOUVEAU : Dossier Médical pour l'IA Gemini
  final int? patientAge;
  final String? medicalConditions; // ex: "Diabète, Ostéoporose"
  final String? medications; // ex: "Aspirine, Insuline"
  final String? bloodType; // ex: "O+"

  BraceletModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.patientName,
    required this.batteryLevel,
    required this.isConnected,
    required this.lastUpdate,
    this.firmwareVersion,
    this.latitude,
    this.longitude,
    this.city,
    this.patientAge,
    this.medicalConditions,
    this.medications,
    this.bloodType,
  });

  factory BraceletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BraceletModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? 'Soignant inconnu',
      patientName: data['patientName'] ?? 'Patient inconnu',
      batteryLevel: data['batteryLevel'] ?? 100,
      isConnected: data['isConnected'] ?? false,
      lastUpdate: data['lastUpdate'] != null
          ? (data['lastUpdate'] as Timestamp).toDate()
          : DateTime.now(),
      firmwareVersion: data['firmwareVersion'],
      // Localisation
      latitude: (data['location']?['lat'] as num?)?.toDouble(),
      longitude: (data['location']?['lon'] as num?)?.toDouble(),
      city: data['location']?['city'],
      // Dossier médical
      patientAge: data['medicalRecord']?['age'],
      medicalConditions: data['medicalRecord']?['conditions'],
      medications: data['medicalRecord']?['medications'],
      bloodType: data['medicalRecord']?['bloodType'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'patientName': patientName,
      'batteryLevel': batteryLevel,
      'isConnected': isConnected,
      'lastUpdate': FieldValue.serverTimestamp(),
      'firmwareVersion': firmwareVersion,
      'location': {
        'lat': latitude,
        'lon': longitude,
        'city': city,
      },
      'medicalRecord': {
        'age': patientAge,
        'conditions': medicalConditions,
        'medications': medications,
        'bloodType': bloodType,
      }
    };
  }

  String get batteryStatus {
    if (batteryLevel > 50) return 'Excellente';
    if (batteryLevel > 20) return 'Moyenne';
    return 'Faible - À recharger';
  }

  String get connectionStatus {
    return isConnected ? 'En ligne' : 'Hors ligne';
  }
}
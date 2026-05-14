import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? cin;
  final UserRole role;
  final String? braceletId;
  final String? patientName;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.cin,
    required this.role,
    this.braceletId,
    this.patientName,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      cin: data['cin'],
      role: UserRole.values.firstWhere(
            (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.soignant,
      ),
      braceletId: data['braceletId'],
      patientName: data['patientName'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'cin': cin,
      'role': role.name,
      'braceletId': braceletId,
      'patientName': patientName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get hasPatient => braceletId != null && patientName != null;
}

enum UserRole {
  patient,
  soignant,
  superAdmin,
}
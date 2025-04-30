import 'package:cloud_firestore/cloud_firestore.dart';

class UserInformation {
  String? id;
  String name;
  String password;
  DateTime createdAt;
  DateTime updatedAt;

  UserInformation({
    this.id,
    required this.name,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserInformation.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return UserInformation(
      id: documentId,
      name: data['name'],
      password: data['password'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'password': password,
      'created_at': Timestamp.fromDate(
        createdAt,
      ), // Convert DateTime to Timestamp
      'updated_at': Timestamp.fromDate(
        updatedAt,
      ), // Convert DateTime to Timestamp
    };
  }
}

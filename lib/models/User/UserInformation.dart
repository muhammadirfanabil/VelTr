import 'package:cloud_firestore/cloud_firestore.dart';

class UserInformation {
  String? id;
  String? name;
  String emailAddress;
  String password;
  DateTime createdAt;
  DateTime updatedAt;

  UserInformation({
    this.id,
    this.name,
    required this.emailAddress,
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
      emailAddress: data['emailAddress'],
      password: data['password'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emailAddress': emailAddress,
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

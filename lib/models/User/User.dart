import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String? id;
  String emailAddress;
  String password;

  User({
    this.id,
    required this.emailAddress,
    required this.password,
  });

  factory User.fromMap(
      Map<String, dynamic> data,
      String documentId,
      ) {
    return User(
      id: documentId,
      emailAddress: data['emailAddress'],
      password: data['password'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailAddress': emailAddress,
      'password': password,
    };
  }
}

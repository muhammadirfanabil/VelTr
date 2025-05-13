import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInformation {
  String id;
  String name;
  String emailAddress;
  String password;
  DateTime createdAt;
  DateTime updatedAt;

  UserInformation({
    required this.id,
    required this.name,
    required this.emailAddress,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  UserInformation copyWith({
    String? id,
    String? name,
    String? emailAddress,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserInformation(
      id: id ?? this.id,
      name: name ?? this.name,
      emailAddress: emailAddress ?? this.emailAddress,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Register user in Firebase Authentication and Firestore
  static Future<void> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Get the user ID from Firebase Authentication
      String userId = userCredential.user!.uid;

      // Create a UserInformation object
      UserInformation userInformation = UserInformation(
        id: userId,
        name: name,
        emailAddress: email,
        password: password,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user information to Firestore
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(userId)
          .set(userInformation.toMap());
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }
}

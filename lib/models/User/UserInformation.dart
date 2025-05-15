import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInformation {
  String id;
  String name;
  String emailAddress;
  DateTime createdAt;
  DateTime updatedAt;

  UserInformation({
    required this.id,
    required this.name,
    required this.emailAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  UserInformation copyWith({
    String? id,
    String? name,
    String? emailAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserInformation(
      id: id ?? this.id,
      name: name ?? this.name,
      emailAddress: emailAddress ?? this.emailAddress,
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
      name: data['name'] ?? '',
      emailAddress: data['emailAddress'] ?? '',
      createdAt:
          data['created_at'] != null
              ? (data['created_at'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          data['updated_at'] != null
              ? (data['updated_at'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emailAddress': emailAddress,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Register user in Firebase Authentication and Firestore
  static Future<UserInformation> registerUser({
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user information to Firestore
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(userId)
          .set(userInformation.toMap());

      return userInformation;
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  /// Ensure user data exists in Firestore after login
  static Future<UserInformation> ensureUserExistsAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user is currently logged in.");
    }

    try {
      DocumentReference userDoc = FirebaseFirestore.instance
          .collection('users_information')
          .doc(user.uid);

      DocumentSnapshot docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // If the document doesn't exist, create it
        UserInformation userInformation = UserInformation(
          id: user.uid,
          name: user.displayName ?? 'No Name',
          emailAddress: user.email ?? 'No Email',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userDoc.set(userInformation.toMap());
        return userInformation;
      } else {
        // Return existing user information
        return UserInformation.fromMap(
          docSnapshot.data() as Map<String, dynamic>,
          user.uid,
        );
      }
    } catch (e) {
      throw Exception('Failed to ensure user exists: $e');
    }
  }

  /// Get user information from Firestore
  static Future<UserInformation?> getUserInformation(String userId) async {
    try {
      DocumentSnapshot docSnapshot =
          await FirebaseFirestore.instance
              .collection('users_information')
              .doc(userId)
              .get();

      if (docSnapshot.exists) {
        return UserInformation.fromMap(
          docSnapshot.data() as Map<String, dynamic>,
          userId,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user information: $e');
    }
  }

  /// Update user information in Firestore
  Future<void> updateInformation() async {
    try {
      this.updatedAt = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(id)
          .update(toMap());
    } catch (e) {
      throw Exception('Failed to update user information: $e');
    }
  }

  /// Update specific user fields
  static Future<void> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      fields['updated_at'] = Timestamp.fromDate(DateTime.now());
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(userId)
          .update(fields);
    } catch (e) {
      throw Exception('Failed to update user fields: $e');
    }
  }
}

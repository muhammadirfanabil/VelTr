import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class userInformation {
  String id;
  String name;
  String emailAddress;
  String phoneNumber;
  List<String> vehicleIds; // List of vehicle IDs owned by the user
  DateTime createdAt;
  DateTime updatedAt;

  userInformation({
    required this.id,
    required this.name,
    required this.emailAddress,
    this.phoneNumber = '',
    this.vehicleIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });
  userInformation copyWith({
    String? id,
    String? name,
    String? emailAddress,
    String? phoneNumber,
    List<String>? vehicleIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return userInformation(
      id: id ?? this.id,
      name: name ?? this.name,
      emailAddress: emailAddress ?? this.emailAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vehicleIds: vehicleIds ?? this.vehicleIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  factory userInformation.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return userInformation(
      id: documentId,
      name: data['name'] ?? '',
      emailAddress: data['email'] ?? data['emailAddress'] ?? '',
      phoneNumber: data['phone_number'] ?? data['phoneNumber'] ?? '',
      vehicleIds: List<String>.from(
        data['vehicleIds'] ?? data['vehicle_ids'] ?? [],
      ),
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
  factory userInformation.fromJson(Map<String, dynamic> json) {
    return userInformation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emailAddress: json['emailAddress'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      vehicleIds: List<String>.from(json['vehicleIds'] ?? []),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': emailAddress,
      'phone_number': phoneNumber,
      'vehicleIds': vehicleIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emailAddress': emailAddress,
      'phoneNumber': phoneNumber,
      'vehicleIds': vehicleIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Register user in Firebase Authentication and Firestore
  static Future<userInformation> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Get the user ID from Firebase Authentication
      String userId =
          userCredential.user!.uid; // Create a UserInformation object
      userInformation UserInformation = userInformation(
        id: userId,
        name: name,
        emailAddress: email,
        vehicleIds: [], // Initialize with empty vehicle list
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ); // Save user information to Firestore
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(userId)
          .set(UserInformation.toMap());

      return UserInformation;
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  /// Ensure user data exists in Firestore after login
  static Future<userInformation> ensureUserExistsAfterLogin() async {
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
        userInformation UserInformation = userInformation(
          id: user.uid,
          name: user.displayName ?? 'No Name',
          emailAddress: user.email ?? 'No Email',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userDoc.set(UserInformation.toMap());
        return UserInformation;
      } else {
        // Return existing user information
        return userInformation.fromMap(
          docSnapshot.data() as Map<String, dynamic>,
          user.uid,
        );
      }
    } catch (e) {
      throw Exception('Failed to ensure user exists: $e');
    }
  }

  /// Get user information from Firestore
  static Future<userInformation?> getUserInformation(String userId) async {
    try {
      DocumentSnapshot docSnapshot =
          await FirebaseFirestore.instance
              .collection('users_information')
              .doc(userId)
              .get();

      if (docSnapshot.exists) {
        return userInformation.fromMap(
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/User/userInformation.dart';

// Handle CRUD for User
class UserService {
  final CollectionReference usersRef = FirebaseFirestore.instance.collection(
    'users_information', // Name of the collection in Firestore
  );

  /// Add a new user to Firestore with Firebase Auth UID as document ID
  Future<void> addUser(userInformation user) async {
    try {
      // Use the user's Firebase Auth UID as the document ID
      await usersRef.doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  /// Add a new user with auto-generated ID (for cases where you don't have UID)
  Future<void> addUserWithAutoId(userInformation user) async {
    try {
      final docRef = usersRef.doc(); // Auto-generates ID
      await docRef.set(user.copyWith(id: docRef.id).toMap());
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  Stream<List<userInformation>> getUsers() {
    return usersRef.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map(
                (doc) => userInformation.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
    );
  }

  /// Update an existing user
  Future<void> updateUser(userInformation user) async {
    try {
      await usersRef.doc(user.id).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Delete a user by ID
  Future<void> deleteUser(String id) async {
    try {
      await usersRef.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Fetch a single user by ID (Firebase Auth UID)
  Future<userInformation?> getUserById(String id) async {
    try {
      final doc = await usersRef.doc(id).get();
      if (doc.exists) {
        return userInformation.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  /// Get user information by Firebase Auth UID (alias for getUserById)
  Future<userInformation?> getUserInformation(String uid) async {
    return await getUserById(uid);
  }

  /// Load user data with fallback to Firebase Auth user data
  Future<Map<String, dynamic>> loadUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Get user data from Firestore using Firebase Auth UID
        userInformation? userInfo = await getUserById(currentUser.uid);

        if (userInfo != null) {
          return {
            'userInfo': userInfo,
            'name': userInfo.name,
            'email': userInfo.emailAddress,
            'phoneNumber':
                currentUser.phoneNumber ??
                'No phone number', // Get from Firebase Auth
            'isLoading': false,
          };
        } else {
          // If user not found in Firestore, return Firebase Auth data
          return {
            'userInfo': null,
            'name': currentUser.displayName ?? 'No name found',
            'email': currentUser.email ?? 'No email found',
            'phoneNumber': currentUser.phoneNumber ?? 'No phone number',
            'isLoading': false,
          };
        }
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      throw Exception('Error loading user data: $e');
    }
  }

  /// Create or update user data using Firebase Auth UID as document ID
  Future<userInformation> updateUserData(
    String name,
    String email,
    userInformation? currentUserInfo,
  ) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        if (currentUserInfo != null) {
          // Update existing user
          final updatedUser = currentUserInfo.copyWith(
            name: name,
            emailAddress: email,
            updatedAt: DateTime.now(),
          );

          await updateUser(updatedUser);
          return updatedUser;
        } else {
          // Create new user info with Firebase Auth UID as document ID
          final newUserInfo = userInformation(
            id: currentUser.uid, // Use Firebase Auth UID
            name: name,
            emailAddress: email,
            vehicleIds: [], // Initialize with empty vehicle list
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await addUser(newUserInfo); // This will use UID as document ID
          return newUserInfo;
        }
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      throw Exception('Error updating user data: $e');
    }
  }

  /// Refresh user profile data - useful for UI refresh operations
  Future<Map<String, dynamic>> refreshUserProfile() async {
    try {
      return await loadUserData();
    } catch (e) {
      throw Exception('Error refreshing profile: $e');
    }
  }

  /// Validate user data before updates
  bool validateUserData(String name, String email) {
    if (name.trim().isEmpty) {
      throw Exception('Name cannot be empty');
    }

    if (email.trim().isEmpty) {
      throw Exception('Email cannot be empty');
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email.trim())) {
      throw Exception('Please enter a valid email address');
    }

    return true;
  }

  /// Update user profile with validation
  Future<userInformation> updateUserProfile(
    String name,
    String email,
    userInformation? currentUserInfo,
  ) async {
    try {
      // Validate data first
      validateUserData(name, email);

      // Call the existing update method
      return await updateUserData(name.trim(), email.trim(), currentUserInfo);
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }

  /// Add a vehicle to user's vehicle list
  Future<void> addVehicleToUser(String userId, String vehicleId) async {
    try {
      final userInfo = await getUserById(userId);
      if (userInfo != null) {
        List<String> vehicleIds = List<String>.from(userInfo.vehicleIds);
        if (!vehicleIds.contains(vehicleId)) {
          vehicleIds.add(vehicleId);
          final updatedUser = userInfo.copyWith(
            vehicleIds: vehicleIds,
            updatedAt: DateTime.now(),
          );
          await updateUser(updatedUser);
        }
      }
    } catch (e) {
      throw Exception('Failed to add vehicle to user: $e');
    }
  }

  /// Remove a vehicle from user's vehicle list
  Future<void> removeVehicleFromUser(String userId, String vehicleId) async {
    try {
      final userInfo = await getUserById(userId);
      if (userInfo != null) {
        List<String> vehicleIds = List<String>.from(userInfo.vehicleIds);
        vehicleIds.remove(vehicleId);
        final updatedUser = userInfo.copyWith(
          vehicleIds: vehicleIds,
          updatedAt: DateTime.now(),
        );
        await updateUser(updatedUser);
      }
    } catch (e) {
      throw Exception('Failed to remove vehicle from user: $e');
    }
  }

  /// Get user's vehicle IDs
  Future<List<String>> getUserVehicleIds(String userId) async {
    try {
      final userInfo = await getUserById(userId);
      return userInfo?.vehicleIds ?? [];
    } catch (e) {
      throw Exception('Failed to get user vehicles: $e');
    }
  }

  /// Initialize user with empty vehicle list using Firebase Auth UID
  Future<userInformation> createUserWithEmptyVehicles(
    String name,
    String email,
    String userId, // This should be the Firebase Auth UID
  ) async {
    try {
      final newUserInfo = userInformation(
        id: userId, // Use Firebase Auth UID as document ID
        name: name,
        emailAddress: email,
        vehicleIds: [], // Initialize with empty vehicle list
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addUser(newUserInfo); // This will use UID as document ID
      return newUserInfo;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Create user document immediately after Firebase Auth registration
  Future<userInformation> createUserAfterRegistration(
    String name,
    String email,
  ) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final newUserInfo = userInformation(
          id: currentUser.uid, // Use Firebase Auth UID
          name: name,
          emailAddress: email,
          vehicleIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await addUser(newUserInfo);
        return newUserInfo;
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      throw Exception('Failed to create user after registration: $e');
    }
  }

  /// Check if user document exists in Firestore
  Future<bool> userDocumentExists(String uid) async {
    try {
      final doc = await usersRef.doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Ensure user document exists, create if it doesn't
  Future<userInformation> ensureUserDocument() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final exists = await userDocumentExists(currentUser.uid);

        if (!exists) {
          // Create user document with Firebase Auth data as fallback
          return await createUserAfterRegistration(
            currentUser.displayName ?? 'User',
            currentUser.email ?? 'No email',
          );
        } else {
          // Return existing user data
          final userInfo = await getUserById(currentUser.uid);
          return userInfo!;
        }
      } else {
        throw Exception('No authenticated user found');
      }
    } catch (e) {
      throw Exception('Failed to ensure user document: $e');
    }
  }
}

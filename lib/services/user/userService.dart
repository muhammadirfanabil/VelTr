import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/User/userInformation.dart';

// Handle CRUD for User
class UserService {
  final CollectionReference usersRef = FirebaseFirestore.instance.collection(
    'users_information', // Name of the collection in Firestore
  );

  /// Add a new user to Firestore
  Future<void> addUser(userInformation user) async {
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
  /// Fetch a single user by ID
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

  /// Load user data with fallback to Firebase Auth user data
  Future<Map<String, dynamic>> loadUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Get user data from Firestore
        userInformation? userInfo = await getUserById(currentUser.uid);
        
        if (userInfo != null) {
          return {
            'userInfo': userInfo,
            'name': userInfo.name,
            'email': userInfo.emailAddress,
            'phoneNumber': '-', // UserInformation model doesn't have phone field yet
            'isLoading': false,
          };
        } else {
          // If user not found in Firestore, return Firebase Auth data
          return {
            'userInfo': null,
            'name': currentUser.displayName ?? 'No name found',
            'email': currentUser.email ?? 'No email found',
            'phoneNumber': '-',
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

  /// Update user data or create new user if doesn't exist
  Future<userInformation> updateUserData(String name, String email, userInformation? currentUserInfo) async {
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
          // Create new user info if it doesn't exist
          final newUserInfo = userInformation(
            id: currentUser.uid,
            name: name,
            emailAddress: email,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await addUser(newUserInfo);
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
  Future<userInformation> updateUserProfile(String name, String email, userInformation? currentUserInfo) async {
    try {
      // Validate data first
      validateUserData(name, email);
      
      // Call the existing update method
      return await updateUserData(name.trim(), email.trim(), currentUserInfo);
    } catch (e) {
      throw Exception('Profile update failed: $e');
    }
  }
}

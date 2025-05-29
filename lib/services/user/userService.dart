import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Get a stream of all users
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
}

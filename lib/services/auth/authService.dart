import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  /// Get current user ID
  static String? getCurrentUserId() {
    final User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  /// Get current user
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Login with email and password
  static Future<UserCredential> loginWithEmail(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Login using Google Sign-In
  static Future<UserCredential> loginWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception("Login canceled.");

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final uid = userCredential.user!.uid;
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(uid)
            .get();

    if (!userDoc.exists) {
      throw Exception("not_registered");
    }

    return userCredential;
  }

  /// Register with email and password, and save extra info to Firestore
  static Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String address,
    required String phoneNumber,
  }) async {
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final uid = userCredential.user!.uid;

    await FirebaseFirestore.instance
        .collection('users_information')
        .doc(uid)
        .set({
          'name': name,
          'email': email,
          'address': address,
          'phone_number': phoneNumber,
          'created_at': FieldValue.serverTimestamp(),
        });

    return userCredential;
  }

  /// Register Google user in Firestore with additional info
  static Future<UserCredential> registerGoogleUser({
    required String email,
    required String name,
    required String address,
    required String phoneNumber,
  }) async {
    // Get the currently signed-in Google user
    final googleSignIn = GoogleSignIn();
    final googleUser = googleSignIn.currentUser;

    if (googleUser == null) {
      // If no current user, perform sign-in
      final newGoogleUser = await googleSignIn.signIn();
      if (newGoogleUser == null) throw Exception("Login canceled.");

      final googleAuth = await newGoogleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final uid = userCredential.user!.uid;

      // Save user information to Firestore
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(uid)
          .set({
            'name': name,
            'email': email,
            'address': address,
            'phone_number': phoneNumber,
            'created_at': FieldValue.serverTimestamp(),
            'google_signin': true,
          });

      return userCredential;
    } else {
      // User is already signed in with Google, just create the Firestore record
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Re-authenticate with Google if Firebase user is null
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final uid = userCredential.user!.uid;

        // Save user information to Firestore
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(uid)
            .set({
              'name': name,
              'email': email,
              'address': address,
              'phone_number': phoneNumber,
              'created_at': FieldValue.serverTimestamp(),
              'google_signin': true,
            });

        return userCredential;
      } else {
        // Firebase user exists, just update Firestore
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(currentUser.uid)
            .set({
              'name': name,
              'email': email,
              'address': address,
              'phone_number': phoneNumber,
              'created_at': FieldValue.serverTimestamp(),
              'google_signin': true,
            });
        // Return the current authentication state since user is already signed in
        // We can't create a UserCredential manually, so let's re-authenticate
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        return userCredential;
      }
    }
  }

  /// Logout from the app
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  /// Retrieves the current user data from Firestore
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Get user data from Firestore
        final DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users_information')
                .doc(currentUser.uid)
                .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // Add email from Firebase Auth if not present in Firestore
          userData['email'] = userData['email'] ?? currentUser.email;
          return userData;
        } else {
          // Return basic info if user document doesn't exist
          return {'email': currentUser.email};
        }
      }
      return null;
    } catch (e) {
      // Use proper error handling
      print('Error loading user data: $e');
      return null;
    }
  }

  /// Update user data in Firestore
  static Future<bool> updateUserData(String name, String email) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(currentUser.uid)
            .update({
              'name': name,
              'email': email,
              'updated_at': FieldValue.serverTimestamp(),
            });

        return true;
      }
      return false;
    } catch (e) {
      // Use logger in production instead
      print('Error updating user data: $e');
      return false;
    }
  }
}

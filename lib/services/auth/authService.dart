import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM token management and listeners
  static Future<void> _initializeFCMTokenManagement() async {
    try {
      // Request notification permissions
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Get and save the current FCM token
      await _saveFCMToken();

      // Listen for token refresh and update Firestore
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
        _saveFCMToken();
      });
    } catch (e) {
      print('Error initializing FCM token management: $e');
    }
  }

  /// Save or update FCM token in user's Firestore document
  static Future<void> _saveFCMToken() async {
    try {
      final String? token = await _messaging.getToken();
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (token != null && currentUser != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('users_information')
            .doc(currentUser.uid);

        // Use merge: true to create the document if it doesn't exist
        await userDocRef.set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcm_token_updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('FCM token saved successfully');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from user's Firestore document
  static Future<void> _removeFCMToken() async {
    try {
      final String? token = await _messaging.getToken();
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (token != null && currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(currentUser.uid)
            .update({
              'fcmTokens': FieldValue.arrayRemove([token]),
              'fcm_token_removed_at': FieldValue.serverTimestamp(),
            });

        print('FCM token removed successfully');
      }
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }

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
  static Future<UserCredential> loginWithEmail(
    String email,
    String password,
  ) async {
    final userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    // Initialize FCM token management after successful login
    await _initializeFCMTokenManagement();

    return userCredential;
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

    // Initialize FCM token management after successful login
    await _initializeFCMTokenManagement();

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

    // Initialize FCM token management after successful registration
    await _initializeFCMTokenManagement();

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
      ); // Sign in with Firebase Auth
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

      // Initialize FCM token management after successful registration
      await _initializeFCMTokenManagement();

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
        final uid =
            userCredential.user!.uid; // Save user information to Firestore
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

        // Initialize FCM token management after successful registration
        await _initializeFCMTokenManagement();

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

        // Initialize FCM token management after successful registration
        await _initializeFCMTokenManagement();

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
    // Remove FCM token before signing out
    await _removeFCMToken();

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

  /// Verify current password by re-authenticating the user
  static Future<bool> verifyCurrentPassword(String currentPassword) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null || currentUser.email == null) {
        throw Exception('No user is currently signed in');
      }

      // Create credential for re-authentication
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      // Try to re-authenticate
      await currentUser.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase auth errors
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return false;
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later.');
        case 'user-mismatch':
          throw Exception('User credentials do not match.');
        case 'user-not-found':
          throw Exception('User account not found.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to verify password: $e');
    }
  }

  /// Change user password
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      // First verify the current password
      final isCurrentPasswordValid = await verifyCurrentPassword(
        currentPassword,
      );
      if (!isCurrentPasswordValid) {
        throw Exception('Current password is incorrect');
      }

      // Update the password
      await currentUser.updatePassword(newPassword);

      // Log the password change in Firestore (optional, for security audit)
      await FirebaseFirestore.instance
          .collection('users_information')
          .doc(currentUser.uid)
          .update({'password_last_changed': FieldValue.serverTimestamp()});

      return true;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase auth errors
      switch (e.code) {
        case 'weak-password':
          throw Exception(
            'The new password is too weak. Please choose a stronger password.',
          );
        case 'requires-recent-login':
          throw Exception(
            'For security reasons, please log out and log back in before changing your password.',
          );
        case 'too-many-requests':
          throw Exception('Too many requests. Please try again later.');
        default:
          throw Exception('Failed to change password: ${e.message}');
      }
    } catch (e) {
      if (e.toString().contains('Current password is incorrect')) {
        rethrow;
      }
      throw Exception('Failed to change password: $e');
    }
  }

  /// Validate password strength
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null; // Password is valid
  }
}

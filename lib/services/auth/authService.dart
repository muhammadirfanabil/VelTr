import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
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
    // First, perform the Google sign-in
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception("Login canceled.");

    final googleAuth = await googleUser.authentication;

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
  }

  /// Logout from the app
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }
}

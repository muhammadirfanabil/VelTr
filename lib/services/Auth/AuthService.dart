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
    if (googleUser == null) throw Exception("Login dibatalkan");

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
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

    await FirebaseFirestore.instance.collection('user_information').doc(uid).set({
      'name': name,
      'email': email,
      'address': address,
      'phone_number': phoneNumber,
      'created_at': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }
}

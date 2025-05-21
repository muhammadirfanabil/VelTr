import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterOne extends StatefulWidget {
  const RegisterOne({super.key});

  @override
  State<RegisterOne> createState() => _RegisterOneState();
}

class _RegisterOneState extends State<RegisterOne> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _isEmailOrUsernameTaken(String email, String username) async {
    final query = await _firestore.collection('users_information').get();
    for (var doc in query.docs) {
      final data = doc.data();
      if (data['emailAddress'] == email || data['name'] == username) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _registerUserToFirestore({bool fromGoogle = false}) async {
    final email = _emailController.text.trim();
    final username = _nameController.text.trim();

    if (await _isEmailOrUsernameTaken(email, username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email or Username already registered')),
      );
      return false;
    }

    final userData = {
      'name': username,
      'emailAddress': email,
      'password': fromGoogle ? null : _passwordController.text.trim(),
      'created_at': DateTime.now(),
      'updated_at': DateTime.now(),
    };

    final docRef = _firestore.collection('users_information').doc(email);
    await docRef.set(userData);
    return true;
  }

  void _goToStep2({bool fromGoogle = false}) async {
    if (!fromGoogle) {
      final success = await _registerUserToFirestore();
      if (!success) return;
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled sign-in
        return;
      }

      final email = googleUser.email;
      final displayName = googleUser.displayName ?? 'No Name';

      final usersCollection = _firestore.collection('users_information');

      // Query Firestore for existing user by email
      final querySnapshot =
          await usersCollection
              .where('emailAddress', isEqualTo: email)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        // User not found, create new doc
        await usersCollection.add({
          'name': displayName,
          'emailAddress': email,
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
          // You can add more fields as needed here
        });
      }

      // Update local state for UI if you want
      setState(() {
        _nameController.text = displayName;
        _emailController.text = email;
      });

      // Navigate forward after sign-in
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Google sign-in error: $e');
      // You can show an error dialog/snackbar here if you want
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 40),
              SvgPicture.asset('assets/icons/appicon1.svg', height: 90),
              const SizedBox(height: 10),
              const Text('Track to Safety.', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              Container(
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Username
                      _buildTextField(
                        controller: _nameController,
                        label: 'Username',
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? 'This field is required'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? 'This field is required'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        obscureText: _obscurePassword,
                        toggleVisibility:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? 'This field is required'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        obscureText: _obscureConfirmPassword,
                        toggleVisibility:
                            () => setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
                        validator: (val) {
                          if (val == null || val.isEmpty)
                            return 'This field is required';
                          if (val != _passwordController.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // NEXT Button
                      _loading
                          ? const CircularProgressIndicator()
                          : GestureDetector(
                            onTap: () async {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _loading = true);
                                await _registerUserToFirestore();
                                setState(() => _loading = false);
                                _goToStep2();
                              }
                            },
                            child: _buildGradientButton('Sign Up'),
                          ),
                      const SizedBox(height: 16),

                      // Google Sign-in
                      GestureDetector(
                        onTap: _loginWithGoogle,
                        child: _buildGoogleButton(),
                      ),
                      const SizedBox(height: 24),

                      // Already have account?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already Have an Account?',
                            style: TextStyle(color: Colors.black38),
                          ),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/login'),
                            child: ShaderMask(
                              shaderCallback:
                                  (bounds) => const LinearGradient(
                                    colors: [
                                      Color(0xFF11468F),
                                      Color(0xFFDA1212),
                                    ],
                                  ).createShader(bounds),
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    VoidCallback? toggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon:
            toggleVisibility != null
                ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: toggleVisibility,
                )
                : null,
      ),
      validator: validator,
    );
  }

  Widget _buildGradientButton(String text) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11468F), Color(0xFFDA1212)],
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/icons/google_icon.svg', height: 24),
          const SizedBox(width: 10),
          const Text(
            'Sign in with Google',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

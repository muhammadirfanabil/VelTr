import 'package:flutter/material.dart';
import '../../services/auth/authService.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleSignupScreen extends StatefulWidget {
  final String email;
  final String displayName;

  const GoogleSignupScreen({
    Key? key,
    required this.email,
    required this.displayName,
  }) : super(key: key);

  @override
  State<GoogleSignupScreen> createState() => _GoogleSignupScreenState();
}

class _GoogleSignupScreenState extends State<GoogleSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _completeRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        // Check if user is already registered first
        try {
          await AuthService.loginWithGoogle();
          if (!mounted) return;

          // User is already registered, show message and go to home
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User already registered! Signing in...'),
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
          return;
        } catch (e) {
          // If error contains "not_registered", continue with registration
          if (!e.toString().contains("not_registered")) {
            // Some other error occurred
            rethrow;
          }
        }

        // User is not registered, proceed with registration
        await AuthService.registerGoogleUser(
          email: widget.email,
          name: _nameController.text.trim(),
          address: '',
          phoneNumber: '',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = 'Registration failed: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Complete Registration'),
      ),
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
                        'Complete Your Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signed in as ${widget.email}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Name',
                          hintText: 'How would you like to be called?',
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator:
                            (value) =>
                                value == null || value.isEmpty
                                    ? 'Please enter your name'
                                    : null,
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      _loading
                          ? const CircularProgressIndicator()
                          : GestureDetector(
                            onTap: _completeRegistration,
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF11468F),
                                    Color(0xFFDA1212),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Complete Registration',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),

                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
}

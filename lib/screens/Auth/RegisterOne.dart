import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  void _goToStep2({bool fromGoogle = false}) {
    Navigator.pushNamed(
      context,
      '/registertwo',
      arguments: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': fromGoogle ? null : _passwordController.text.trim(),
        'fromGoogle': fromGoogle,
      },
    );
  }

  Future<void> _loginWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final user = await googleSignIn.signIn();
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email;
      _goToStep2(fromGoogle: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'This Field is Required'
                            : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'This Field is Required'
                            : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'This Field is Required'
                            : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'This Field is Required';
                  if (value != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    _loading
                        ? null
                        : () {
                          if (_formKey.currentState!.validate()) _goToStep2();
                        },
                child: const Text("Next"),
              ),
              TextButton(
                onPressed: _loginWithGoogle,
                child: const Text("Sign in with Google"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

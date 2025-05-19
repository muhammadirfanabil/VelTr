import 'package:flutter/material.dart';
import '../../services/Auth/authService.dart'; // adjust this path as needed

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      try {
        await AuthService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registrasi berhasil")),
        );

        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mendaftar: $e")),
        );
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'No. Telepon'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                )
                    : const Text('Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

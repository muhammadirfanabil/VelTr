import 'package:flutter/material.dart';
import '../../models/User/UserInformation.dart';
import '../../services/User/UserService.dart';

class UserForm extends StatefulWidget {
  final UserInformation? user;

  const UserForm({super.key, this.user});

  @override
  _UserFormState createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  final TextEditingController _emailAddressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  // final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailAddressController.text = widget.user?.emailAddress ?? '';
    _nameController.text = widget.user?.name ?? '';
    // _passwordController.text = widget.user?.password ?? '';
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
        _error = null;
      });

      final now = DateTime.now();
      final user = UserInformation(
        id: widget.user?.id ?? '',
        emailAddress: _emailAddressController.text.trim(),
        name: _nameController.text.trim(),
        // password: _passwordController.text.trim(),
        createdAt: widget.user?.createdAt ?? now,
        updatedAt: now,
      );

      try {
        if (widget.user == null) {
          await _userService.addUser(user);
        } else {
          await _userService.updateUser(user);
        }
        Navigator.of(context).pop();
      } catch (e) {
        setState(() {
          _error = 'Gagal menyimpan data: $e';
        });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Tambah Pengguna' : 'Edit Pengguna'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextFormField(
                  controller: _emailAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 8.0),
              //   child: TextFormField(
              //     controller: _passwordController,
              //     decoration: const InputDecoration(
              //       labelText: 'Password',
              //       prefixIcon: Icon(Icons.lock),
              //       border: OutlineInputBorder(),
              //     ),
              //     obscureText: true,
              //     validator: (value) {
              //       if (value == null || value.isEmpty) {
              //         return 'Password wajib diisi';
              //       }
              //       if (value.length < 6) {
              //         return 'Password minimal 6 karakter';
              //       }
              //       return null;
              //     },
              //   ),
              // ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _saveUser,
          child: _loading
              ? const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../models/users_info.dart';
import '../services/users_services.dart';

class UserForm extends StatefulWidget {
  final UserInformation? user;

  const UserForm({super.key, this.user});

  @override
  _UserFormState createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  late String _emailAdress;
  late String _password;
  final UserService _userService = UserService();

  final TextEditingController _emailAdressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailAdress = widget.user?.emailAdress ?? '';
    _password = widget.user?.password ?? '';
    _emailAdressController.text = _emailAdress;
    _passwordController.text = _password;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Tambah Pengguna' : 'Edit Pengguna'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailAdressController,
              decoration: InputDecoration(labelText: 'Nama'),
              validator:
                  (value) =>
                      value == null || value.isEmpty ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator:
                  (value) =>
                      value == null || value.isEmpty ? 'Wajib diisi' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final now = DateTime.now();
              final user = UserInformation(
                id: widget.user?.id,
                emailAdress: _emailAdressController.text.trim(),
                password: _passwordController.text.trim(),
                createdAt: widget.user?.createdAt ?? now,
                updatedAt: now,
              );
              if (widget.user == null) {
                _userService.addUser(user);
              } else {
                _userService.updateUser(user);
              }
              Navigator.of(context).pop();
            }
          },
          child: Text('Simpan'),
        ),
      ],
    );
  }
}

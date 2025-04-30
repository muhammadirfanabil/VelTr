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
  late String _name;
  late String _password;
  final UserService _userService = UserService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? '';
    _password = widget.user?.password ?? '';
    _nameController.text = _name;
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
              controller: _nameController,
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
                name: _nameController.text.trim(),
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

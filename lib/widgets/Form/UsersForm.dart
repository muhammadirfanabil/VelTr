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
  late String _emailAddress;
  late String _password;
  final UserService _userService = UserService();

  final TextEditingController _emailAddressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailAddress = widget.user?.emailAddress ?? '';
    _password = widget.user?.password ?? '';
    _emailAddressController.text = _emailAddress;
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
              controller: _emailAddressController,
              decoration: InputDecoration(labelText: 'Email'),
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
                emailAddress: _emailAddressController.text.trim(),
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

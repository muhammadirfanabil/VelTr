import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterTwo extends StatefulWidget {
  const RegisterTwo({super.key});

  @override
  State<RegisterTwo> createState() => _RegisterTwoState();
}

class _RegisterTwoState extends State<RegisterTwo> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _vehicleType;
  bool _loading = false;

  void _submit(Map<String, dynamic> data) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      final status = await Permission.location.request();
      if (status.isGranted) {
        // TODO: Register logic with full data + location
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required")),
        );
      }

      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};

    return Scaffold(
      appBar: AppBar(title: const Text("Register - Step 2")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _vehicleType,
                items:
                    ['Motor', 'Mobil', 'Truk']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (value) => setState(() => _vehicleType = value),
                decoration: const InputDecoration(labelText: 'Tipe Kendaraan'),
                validator:
                    (value) => value == null ? 'Pilih tipe kendaraan' : null,
              ),
              TextFormField(
                controller: _vehicleNameController,
                decoration: const InputDecoration(labelText: 'Nama Kendaraan'),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _plateNumberController,
                decoration: const InputDecoration(labelText: 'Nomor Plat'),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Nomor HP'),
                keyboardType: TextInputType.phone,
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : () => _submit(args),
                child:
                    _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Sign In"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

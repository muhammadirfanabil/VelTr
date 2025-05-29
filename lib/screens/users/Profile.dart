import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../../models/User/userInformation.dart';
import '../../services/User/userService.dart';
import '../../services/Auth/authService.dart';
=======
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
>>>>>>> a969fd623700a31e72347473a58818c5956b88a7

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _name = 'Loading...';
  String _email = 'Loading...';
  String _phoneNumber = '-';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Get user data from Firestore
        final DocumentSnapshot userDoc =
            await _firestore
                .collection('user_information')
                .doc(currentUser.uid)
                .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;

          if (mounted) {
            setState(() {
              _name = userData['name'] ?? 'No name found';
              _email =
                  userData['email'] ?? currentUser.email ?? 'No email found';
              _phoneNumber = userData['phone_number'] ?? '-';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _email = currentUser.email ?? 'No email found';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserData(String name, String email) async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        await _firestore
            .collection('user_information')
            .doc(currentUser.uid)
            .update({
              'name': name,
              'email': email,
              'updated_at': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          setState(() {
            _name = name;
            _email = email;
          });
        }
      }
    } catch (e) {
      print('Error updating user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 100,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            _phoneNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final nameController = TextEditingController(text: _name);
                final emailController = TextEditingController(text: _email);

                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Edit Profile'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                            ),
                            TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _updateUserData(
                                nameController.text.trim(),
                                emailController.text.trim(),
                              );
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("User updated successfully"),
                                  ),
                                );
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // info card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.grey,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShaderMask(
                                          shaderCallback:
                                              (bounds) => const LinearGradient(
                                                colors: [
                                                  Color(0xFF11468F),
                                                  Color(0xFFDA1212),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(
                                                Rect.fromLTWH(
                                                  0,
                                                  0,
                                                  bounds.width,
                                                  bounds.height,
                                                ),
                                              ),
                                          child: Text(
                                            _name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(_email),
                                        Text(_phoneNumber),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Joined 7 Aug 2025',
                                          style: TextStyle(
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/vehicle');
                                    },
                                    icon: const Icon(Icons.directions_bike),
                                    label: const Text('Vehicle Info'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF11468F),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                _buildFullWidthOutlinedButton(
                                  context,
                                  label: 'Track Your Vehicle',
                                  routeName: '/home',
                                  color: Colors.blue,
                                ),
                                _buildFullWidthOutlinedButton(
                                  context,
                                  label: 'Set Range',
                                  routeName: '/set-range',
                                  color: Colors.green,
                                ),
                                _buildFullWidthOutlinedButton(
                                  context,
                                  label: 'Driving History',
                                  routeName: '/history',
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    await _auth.signOut();
                                    if (mounted) {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Log Out',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        '\u00a9 Poliban 2025',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFullWidthOutlinedButton(
    BuildContext context, {
    required String label,
    required String routeName,
    required Color color, // tambahin parameter warna
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton(
        onPressed: () => Navigator.pushNamed(context, routeName),
        style: OutlinedButton.styleFrom(
          foregroundColor: color, // warna teks
          side: BorderSide(color: color), // warna border
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.center,
        ),
        child: Text(label),
      ),
    );
  }
}

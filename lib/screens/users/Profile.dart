import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/User/userInformation.dart';
import '../../services/User/UserService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  bool _isLoading = true;
  userInformation? _userInfo;
  String _name = 'Profile';
  String _email = 'Profile';
  String _phoneNumber = '-';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userService.loadUserData();

      if (mounted) {
        setState(() {
          _userInfo = userData['userInfo'];
          _name = userData['name'];
          _email = userData['email'];
          _phoneNumber = userData['phoneNumber'];
          _isLoading = userData['isLoading'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _userService.refreshUserProfile();

      if (mounted) {
        setState(() {
          _userInfo = userData['userInfo'];
          _name = userData['name'];
          _email = userData['email'];
          _phoneNumber = userData['phoneNumber'];
          _isLoading = userData['isLoading'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile refreshed successfully!')),
        );
      }
    } catch (e) {
      print('Error refreshing profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing profile: $e')));
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final updatedUserInfo = await _userService
                        .updateUserProfile(
                          nameController.text,
                          emailController.text,
                          _userInfo,
                        );

                    if (mounted) {
                      setState(() {
                        _userInfo = updatedUserInfo;
                        _name = updatedUserInfo.name;
                        _email = updatedUserInfo.emailAddress;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error updating user data: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white30,
        toolbarHeight: 60,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: const Text('Profile'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _refreshProfile,
        //     tooltip: 'Refresh Profile',
        //   ),
        // ],
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
                                        Text(
                                          _userInfo?.createdAt != null
                                              ? 'Joined ${_userInfo!.createdAt.toLocal().toString().split(' ')[0]}'
                                              : 'Joined recently',
                                          style: const TextStyle(
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ElevatedButton.icon(
                                  //   onPressed: _showEditProfileDialog,
                                  //   icon: const Icon(Icons.edit),
                                  //   label: const Text('Edit Profile'),
                                  //   style: ElevatedButton.styleFrom(
                                  //     backgroundColor: const Color(0xFF11468F),
                                  //     foregroundColor: Colors.white,
                                  //     shape: RoundedRectangleBorder(
                                  //       borderRadius: BorderRadius.circular(8),
                                  //     ),
                                  //   ),
                                  // ),
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
                                _buildFullWidthOutlinedButton(
                                  context,
                                  label: 'Manage Devices',
                                  routeName: '/device',
                                  color: Colors.orange,
                                ),
                                _buildFullWidthOutlinedButton(
                                  context,
                                  label: 'Manage Vehicle',
                                  routeName: '/vehicle',
                                  color: Colors.purple,
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

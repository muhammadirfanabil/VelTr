import 'package:flutter/material.dart';
import '../../models/User/userInformation.dart';
import '../../services/User/userService.dart';
import '../../services/Auth/authService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<userInformation> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = userInformation.ensureUserExistsAfterLogin();
  }

  void _refreshUserData() {
    setState(() {
      _userFuture = userInformation.ensureUserExistsAfterLogin();
    });
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
              child: FutureBuilder<userInformation>(
                future: _userFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData) {
                    return const Text('No user data found');
                  }

                  final user = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.emailAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        'Phone Number',
                        // user.phoneNumber ?? 'No phone number',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final currentUser =
                    await userInformation.ensureUserExistsAfterLogin();

                final nameController = TextEditingController(
                  text: currentUser.name,
                );
                final emailController = TextEditingController(
                  text: currentUser.emailAddress,
                );

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
                              final updatedUser = currentUser.copyWith(
                                name: nameController.text.trim(),
                                emailAddress: emailController.text.trim(),
                                updatedAt: DateTime.now(),
                              );

                              await UserService().updateUser(updatedUser);
                              Navigator.pop(context); // close dialog
                              _refreshUserData(); // 🔁 refresh FutureBuilder
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("User updated successfully"),
                                ),
                              );
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
        child: FutureBuilder<userInformation>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('No user data found'));
            }

            final user = snapshot.data!;

            return Column(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID: ${user.id}', // ✅ user ID loaded here
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 32),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/vehicle');
                                },
                                icon: const Icon(Icons.directions_bike),
                                label: const Text('Vehicle Information'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF11468F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Joined 7 Aug 2025',
                                style: TextStyle(color: Colors.black45),
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
                                await AuthService.signOut();
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
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
            );
          },
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

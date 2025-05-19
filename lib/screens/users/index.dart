import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/User/userInformation.dart';
import '../../services/User/userService.dart';
import '../../widgets/Form/usersForm.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UserService userService = UserService();

    Future.microtask(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // await UserInformation.ensureUserExistsAfterLogin(user);
        developer.log('User logged in: ${user.email}');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_sharp),
            tooltip: 'Lihat Peta',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/map');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<userInformation>>(
        stream: userService.getUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error: ${snapshot.error}');
            return const Center(child: Text("Terjadi kesalahan"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!;

          if (users.isEmpty) {
            return const Center(child: Text("Belum ada data"));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text("Email: ${user.emailAddress}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => UserForm(user: user),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Hapus Data'),
                                content: Text(
                                  'Yakin ingin menghapus ${user.emailAddress}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          try {
                            await userService.deleteUser(user.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Data dihapus")),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Gagal menghapus data: $e"),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () =>
                showDialog(context: context, builder: (_) => const UserForm()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

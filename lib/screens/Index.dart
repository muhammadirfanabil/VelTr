import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/Auth/AuthService.dart';
import '../../models/User/UserInformation.dart';

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      if (FirebaseAuth.instance.currentUser != null) {
        try {
          final User user = FirebaseAuth.instance.currentUser!;
          await UserInformation.ensureUserExistsAfterLogin();
          developer.log(
            'User existence verified: ${user.email}',
            name: 'IndexScreen',
          );
        } catch (e) {
          developer.log('Error ensuring user exists: $e', name: 'IndexScreen');
        }
      } else {
        developer.log('User not logged in', name: 'IndexScreen');
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    return Scaffold(
      // Navbar
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(02),
        title: const Text('Dashboard'), // or whatever title you want
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'logout') {
                await AuthService.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'profile', child: Text('Profile')),
                  PopupMenuItem(value: 'settings', child: Text('Settings')),
                  PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/images/mainbg.jpg', fit: BoxFit.cover),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildCard(
                  context,
                  title: "Track Your Vehicle",
                  subtitle: "Keep track to where your vehicle is right now!",
                  routeName: "/map",
                  icon: Icons.map_outlined,
                ),
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  title: "Set Active Range",
                  subtitle: "Set your vehicle active range.",
                  routeName: "/set-range",
                  icon: Icons.settings_input_antenna_rounded,
                ),
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  title: "Driving History",
                  subtitle: "See your vehicle’s recent activities.",
                  routeName: "/history",
                  icon: Icons.history,
                ),
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  title: "Vehicle Management",
                  subtitle: "Manage your vehicles.",
                  routeName: "/vehicle",
                  icon: Icons.directions_car,
                ),
                const Spacer(),
                const Text(
                  "Credit Poliban 2025",
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String routeName,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, routeName),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

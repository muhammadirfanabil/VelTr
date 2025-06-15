// Displays user's basic information in an attractive card format

import 'package:flutter/material.dart';
import '../Common/profile_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String phoneNumber;
  final ColorScheme colorScheme;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.colorScheme,
  });

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50.withValues(alpha: .5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ProfileAvatar(name: name, radius: 40, colorScheme: colorScheme),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.email_outlined, email),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.phone_outlined, phoneNumber),
          ],
        ),
      ),
    );
  }
}

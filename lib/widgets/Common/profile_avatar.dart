// a circular avatar with user initials when no profile image is available

import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final ColorScheme colorScheme;

  const ProfileAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.colorScheme,
  });

  String _getAvatarInitial() {
    return name.isNotEmpty && name != 'No Name' ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primary,
      child: Text(
        _getAvatarInitial(),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}

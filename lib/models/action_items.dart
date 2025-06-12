// This Provides a consistent structure for menu items and makes it easy to create reusable action components

import 'package:flutter/material.dart';

class ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final VoidCallback? onTap;

  const ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route = '',
    this.onTap,
  });
}

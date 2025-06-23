// Renders an ActionItem as a ListTile with consistent styling

import 'package:flutter/material.dart';
import '../../models/action_items.dart';

class ActionTile extends StatelessWidget {
  final ActionItem action;
  final ColorScheme colorScheme;

  const ActionTile({
    super.key,
    required this.action,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(action.icon, color: colorScheme.primary, size: 20),
      ),
      title: Text(
        action.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(action.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap:
          action.onTap ??
          () {
            if (action.route.isNotEmpty) {
              Navigator.pushNamed(context, action.route);
            }
          },
    );
  }
}

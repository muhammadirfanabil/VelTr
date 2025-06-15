// Renders a list of quick action items in a card container

import 'package:flutter/material.dart';
import '../../models/action_items.dart';
import '../common/action_tile.dart';

class QuickActionsList extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<ActionItem> actions;

  const QuickActionsList({
    super.key,
    required this.colorScheme,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...actions.map(
            (action) => ActionTile(action: action, colorScheme: colorScheme),
          ),
        ],
      ),
    );
  }
}

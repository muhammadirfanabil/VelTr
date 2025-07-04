import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final String message;

  const LoadingOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

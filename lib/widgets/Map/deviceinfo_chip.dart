import 'package:flutter/material.dart';

class DeviceInfoChip extends StatelessWidget {
  final bool isNoDevicePlaceholder;
  final String? deviceName;
  final bool hasGPSData;
  final VoidCallback onTap;

  const DeviceInfoChip({
    super.key,
    required this.isNoDevicePlaceholder,
    required this.deviceName,
    required this.hasGPSData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isNoDevicePlaceholder) {
      return _buildChip(
        context: context,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        borderColor: colorScheme.primary.withValues(alpha: 0.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              'Add Device',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    if (deviceName == null) return const SizedBox.shrink();

    return _buildChip(
      context: context,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
      borderColor: colorScheme.outline.withValues(alpha: 0.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.two_wheeler, size: 18, color: colorScheme.onSurface),
          const SizedBox(width: 6),
          if (!hasGPSData) ...[
            Icon(Icons.gps_off, size: 16, color: colorScheme.error),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              deviceName!,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required Color backgroundColor,
    required Color borderColor,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

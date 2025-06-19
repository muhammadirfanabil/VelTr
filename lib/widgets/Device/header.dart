import 'package:flutter/material.dart';
import '../../models/Device/device.dart';

class DeviceHeader extends StatelessWidget {
  final Device device;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const DeviceHeader({
    super.key,
    required this.device,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        _buildStatusIcon(colorScheme),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _buildStatusIndicator(theme, colorScheme),
            ],
          ),
        ),
        _buildActionButtons(colorScheme),
      ],
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    final isActive = device.isActive;
    final statusColor = isActive ? colorScheme.primary : colorScheme.error;
    final backgroundColor =
        isActive
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.error.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Icon(Icons.devices, color: statusColor, size: 24),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme, ColorScheme colorScheme) {
    final isActive = device.isActive;
    final statusColor = isActive ? colorScheme.primary : colorScheme.error;
    final statusText = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            device.isActive ? Icons.pause_circle : Icons.play_circle,
            color: device.isActive ? colorScheme.outline : colorScheme.primary,
            size: 28,
          ),
          onPressed: onToggleStatus,
          tooltip: device.isActive ? 'Deactivate Device' : 'Activate Device',
          style: IconButton.styleFrom(
            backgroundColor:
                device.isActive
                    ? colorScheme.outline.withValues(alpha: 0.1)
                    : colorScheme.primary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.edit_outlined, color: Colors.teal, size: 24),
          onPressed: onEdit,
          tooltip: 'Edit Device',
          style: IconButton.styleFrom(
            backgroundColor: Colors.teal.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

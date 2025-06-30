import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BuildInfoGrid extends StatelessWidget {
  final ThemeData theme;
  final String lastUpdate;
  final String connectionQuality;
  final Color connectionQualityColor;
  final bool hasValidCoordinates;
  final String coordinatesText;
  final VoidCallback? onCopyLocation;

  const BuildInfoGrid({
    required this.theme,
    required this.lastUpdate,
    required this.connectionQuality,
    required this.connectionQualityColor,
    required this.hasValidCoordinates,
    required this.coordinatesText,
    this.onCopyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCoordinatesCard(theme),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                icon: Icons.access_time_rounded,
                label: 'Last Update',
                value: _formatLastUpdate(lastUpdate),
                theme: theme,
              ),
            ),
            if (connectionQuality.isNotEmpty) ...[
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.satellite_alt_rounded,
                  label: 'GPS',
                  value: connectionQuality,
                  theme: theme,
                  valueColor: connectionQualityColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCoordinatesCard(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasValidCoordinates ? onCopyLocation : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  hasValidCoordinates
                      ? AppColors.primaryBlue.withOpacity(0.15)
                      : AppColors.border.withOpacity(0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasValidCoordinates
                    ? Icons.my_location_rounded
                    : Icons.location_disabled_rounded,
                size: 16,
                color:
                    hasValidCoordinates
                        ? AppColors.primaryBlue
                        : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasValidCoordinates ? 'GPS Coordinates' : 'GPS Signal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValidCoordinates ? coordinatesText : 'Not available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            hasValidCoordinates
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                        fontFamily: hasValidCoordinates ? 'monospace' : null,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasValidCoordinates) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Formats the last update time
  String _formatLastUpdate(String lastUpdate) {
    try {
      final updatedTime = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(updatedTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (_) {
      return 'Invalid date';
    }
  }
}

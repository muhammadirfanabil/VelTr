import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class LocationDetailsDialog extends StatelessWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String lastUpdated;
  final int? satellites;
  final String connectionQuality;
  final Color connectionQualityColor;
  final VoidCallback? onCopyCoordinates;

  const LocationDetailsDialog({
    this.locationName,
    this.latitude,
    this.longitude,
    required this.lastUpdated,
    this.satellites,
    required this.connectionQuality,
    required this.connectionQualityColor,
    this.onCopyCoordinates,
  });

  bool get hasValidCoordinates {
    return latitude != null &&
        longitude != null &&
        latitude!.abs() <= 90 &&
        longitude!.abs() <= 180 &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: AppColors.primaryBlue,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text('Location Details'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locationName?.isNotEmpty == true) ...[
              DetailRow(
                icon: Icons.place_rounded,
                label: 'Address',
                value: locationName!,
              ),
              const SizedBox(height: 12),
            ],
            if (hasValidCoordinates) ...[
              DetailRow(
                icon: Icons.my_location_rounded,
                label: 'Latitude',
                value: latitude!.toStringAsFixed(6),
                isCoordinate: true,
              ),
              const SizedBox(height: 8),
              DetailRow(
                icon: Icons.my_location_rounded,
                label: 'Longitude',
                value: longitude!.toStringAsFixed(6),
                isCoordinate: true,
              ),
              const SizedBox(height: 12),
            ],
            DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Last Update',
              value: lastUpdated,
            ),
            if ((satellites ?? 0) > 0) ...[
              const SizedBox(height: 8),
              DetailRow(
                icon: Icons.satellite_alt_rounded,
                label: 'Satellites',
                value: '$satellites connected',
              ),
              const SizedBox(height: 8),
              DetailRow(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Signal Quality',
                value: connectionQuality,
                valueColor: connectionQualityColor,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (hasValidCoordinates && onCopyCoordinates != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onCopyCoordinates!();
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Copy Coordinates'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCoordinate;
  final Color? valueColor;

  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isCoordinate = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    fontFamily: isCoordinate ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

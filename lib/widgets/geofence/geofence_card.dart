import 'package:flutter/material.dart';
import '../../models/Geofence/Geofence.dart';

class GeofenceCard extends StatelessWidget {
  final Geofence geofence;
  final VoidCallback onTap;
  final ValueChanged<bool> onStatusChanged;
  final bool isDeleting;

  const GeofenceCard({
    Key? key,
    required this.geofence,
    required this.onTap,
    required this.onStatusChanged,
    this.isDeleting = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = geofence.status;
    final address = geofence.address ?? 'No address specified';
    final activeGradientColor =
        HSLColor.fromColor(colorScheme.primary)
            .withLightness(0.85) // Adjust lightness
            .withSaturation(0.9) // Increase saturation slightly
            .toColor();

    return Material(
      elevation: 1,
      shadowColor: colorScheme.shadow.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isActive
                      ? colorScheme.primary.withOpacity(0.15)
                      : colorScheme.outline.withOpacity(0.08),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 1.0],
              colors: [
                colorScheme.surface,
                isActive
                    ? activeGradientColor.withOpacity(
                      0.04,
                    ) // Reduced opacity to 0.04
                    : colorScheme.surfaceVariant.withOpacity(0.5),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, colorScheme, activeGradientColor),
                if (address != 'No address specified') ...[
                  const SizedBox(height: 12),
                  _buildAddressSection(address, theme, colorScheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    Color activeGradientColor,
  ) {
    return Row(
      children: [
        _buildIcon(colorScheme, activeGradientColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                geofence.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _buildStatusBadge(theme, colorScheme, activeGradientColor),
            ],
          ),
        ),
        _buildSwitch(colorScheme),
      ],
    );
  }

  Widget _buildIcon(ColorScheme colorScheme, Color activeGradientColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            geofence.status
                ? activeGradientColor.withOpacity(0.15)
                : colorScheme.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              geofence.status
                  ? colorScheme.primary.withOpacity(0.2)
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.fence_rounded,
        color:
            geofence.status
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withOpacity(0.8),
        size: 20,
      ),
    );
  }

  Widget _buildStatusBadge(
    ThemeData theme,
    ColorScheme colorScheme,
    Color activeGradientColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            geofence.status
                ? activeGradientColor.withOpacity(0.2)
                : colorScheme.surfaceVariant.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
        border:
            geofence.status
                ? Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 1,
                )
                : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (geofence.status) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            geofence.status ? 'Active' : 'Inactive',
            style: theme.textTheme.labelSmall?.copyWith(
              color:
                  geofence.status
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(ColorScheme colorScheme) {
    return Transform.scale(
      scale: 0.8,
      child: Switch.adaptive(
        value: geofence.status,
        onChanged: isDeleting ? null : onStatusChanged,
        activeColor: colorScheme.primary,
        activeTrackColor: colorScheme.primaryContainer.withOpacity(0.5),
        inactiveThumbColor: colorScheme.outline,
        inactiveTrackColor: colorScheme.surfaceVariant.withOpacity(0.8),
      ),
    );
  }

  Widget _buildAddressSection(
    String address,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 16,
            color: colorScheme.primary.withOpacity(0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.3,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

class VehicleStatusPanel extends StatelessWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? lastUpdated;
  final bool isVehicleOn;
  final VoidCallback toggleVehicleStatus;

  const VehicleStatusPanel({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    required this.isVehicleOn,
    required this.toggleVehicleStatus,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  String get coordinatesText =>
      hasValidCoordinates
          ? 'Lat: ${latitude!.toStringAsFixed(5)} | Lng: ${longitude!.toStringAsFixed(5)}'
          : 'Coordinates Unavailable';

  String get lastActiveText =>
      (lastUpdated?.isNotEmpty ?? false)
          ? 'Last Active: $lastUpdated'
          : 'Waiting...';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLocationInfo(theme),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locationName ?? 'Loading...',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          coordinatesText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: hasValidCoordinates ? Colors.black87 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lastActiveText,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.green[400]),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildNavigateButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildToggleButton()),
      ],
    );
  }

  Widget _buildNavigateButton() {
    return ElevatedButton.icon(
      onPressed:
          hasValidCoordinates
              ? () {
                // TODO: Implement navigation logic
              }
              : null,
      icon: Transform.rotate(
        angle: 0.25 * math.pi,
        child: const Icon(Icons.navigation, size: 20),
      ),
      label: const Text('Navigate', overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: const Color(0xFF7DAEFF).withOpacity(0.25),
        foregroundColor: const Color(0xFF11468F),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildToggleButton() {
    return ElevatedButton.icon(
      onPressed: toggleVehicleStatus,
      icon: Icon(
        isVehicleOn
            ? Icons.power_settings_new
            : Icons.power_settings_new_outlined,
        size: 20,
      ),
      label: Text(
        isVehicleOn ? 'Turn Off' : 'Turn On',
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor:
            isVehicleOn ? Colors.green.shade600 : Colors.red.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

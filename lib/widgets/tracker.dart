import 'package:flutter/material.dart';
import 'dart:math' as math;

class VehicleStatusPanel extends StatelessWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? lastUpdated;
  final String? waktuWita;
  final bool isVehicleOn;
  final VoidCallback toggleVehicleStatus;
  final int? satellites;

  const VehicleStatusPanel({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    required this.waktuWita,
    required this.isVehicleOn,
    required this.toggleVehicleStatus,
    required this.satellites,
  });

  bool get isOnline {
    if (lastUpdated == null || lastUpdated!.isEmpty) return false;

    try {
      final updatedTime = DateTime.parse(lastUpdated!);
      final now = DateTime.now();
      final difference = now.difference(updatedTime).inMinutes;
      return difference <= 1;
    } catch (_) {
      return false;
    }
  }

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
            // Online/offline status di pojok kanan atas
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  size: 14,
                  color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isOnline ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              locationName ?? 'Loading...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (isOnline && satellites != null)
              Text(
                'Satellites: $satellites',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
            const SizedBox(height: 8),

            if (latitude != null && longitude != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Lat: ${latitude!.toStringAsFixed(5)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Lng: ${longitude!.toStringAsFixed(5)}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Coordinates Unavailable',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              (lastUpdated?.isNotEmpty ?? false)
                  ? 'Last Active: $lastUpdated'
                  : 'Waiting...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green[400],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (latitude != null && longitude != null)
                            ? () {
                              // TODO: Implement navigation logic
                            }
                            : null,
                    icon: Transform.rotate(
                      angle: 0.25 * math.pi,
                      child: const Icon(Icons.navigation, size: 20),
                    ),
                    label: const Text(
                      'Navigate',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(
                        0xFF7DAEFF,
                      ).withOpacity(0.25),
                      foregroundColor: const Color(0xFF11468F),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
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
                          isVehicleOn
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

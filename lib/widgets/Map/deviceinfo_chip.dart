import 'package:flutter/material.dart';

class DeviceInfoChip extends StatelessWidget {
  final String? deviceName;
  final bool hasGPSData;
  final VoidCallback onTap;

  const DeviceInfoChip({
    Key? key,
    required this.deviceName,
    required this.hasGPSData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (deviceName == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            if (!hasGPSData) ...[
              const Icon(Icons.gps_off, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
            ],
            Text(
              deviceName!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

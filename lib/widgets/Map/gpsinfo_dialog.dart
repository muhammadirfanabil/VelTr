import 'package:flutter/material.dart';

class GPSInfoDialog extends StatelessWidget {
  final String? deviceName;
  final String? currentDeviceId;
  final VoidCallback onRetry;

  const GPSInfoDialog({
    Key? key,
    required this.deviceName,
    required this.currentDeviceId,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 28),
          SizedBox(width: 8),
          Text('GPS Information'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GPS data is not currently available for this device.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            'Device: ${deviceName ?? currentDeviceId}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'You can still:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('• View the map interface'),
          const Text('• Access other app features'),
          const Text('• Control device relay status'),
          const Text('• Switch to another vehicle'),
          const Text('• Return later when GPS is available'),
          const SizedBox(height: 16),
          const Text(
            'To enable GPS tracking:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('• Ensure device is powered on'),
          const Text('• Check GPS module functionality'),
          const Text('• Verify network connection'),
          const Text('• Confirm data transmission to server'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          child: const Text('Retry'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

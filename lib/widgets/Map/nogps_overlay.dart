import 'package:flutter/material.dart';

class NoGPSDetailsDialog extends StatelessWidget {
  final String firestoreId;
  final String? deviceName;
  final String? currentDeviceId;
  final VoidCallback onRetry;

  const NoGPSDetailsDialog({
    super.key,
    required this.firestoreId,
    this.deviceName,
    this.currentDeviceId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 28),
          SizedBox(width: 8),
          Text('Device Information'),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Details:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Firestore ID: $firestoreId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                if (deviceName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Device Name: $deviceName',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (currentDeviceId != null &&
                    currentDeviceId != firestoreId) ...[
                  const SizedBox(height: 4),
                  Text(
                    'MAC Address: $currentDeviceId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
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

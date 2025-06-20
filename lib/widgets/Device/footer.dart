import 'package:flutter/material.dart';
import '../../models/Device/device.dart';

class DeviceFooter extends StatelessWidget {
  final Device device;

  const DeviceFooter({Key? key, required this.device}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Created: ${_formatDate(device.createdAt)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        Text(
          'ID: ${device.id.substring(0, 8)}...',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) =>
      '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}

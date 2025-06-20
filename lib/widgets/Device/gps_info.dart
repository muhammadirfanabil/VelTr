import 'package:flutter/material.dart';
import '../../models/Device/device.dart';

class DeviceGPSInfo extends StatelessWidget {
  final Device device;

  const DeviceGPSInfo({Key? key, required this.device}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            device.hasValidGPS ? Icons.gps_fixed : Icons.gps_off,
            size: 16,
            color: device.hasValidGPS ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              device.hasValidGPS
                  ? 'GPS: ${device.coordinatesString}'
                  : 'No GPS data',
              style: TextStyle(
                color: device.hasValidGPS ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

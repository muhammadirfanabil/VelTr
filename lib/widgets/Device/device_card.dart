import 'package:flutter/material.dart';
import '../../models/Device/device.dart';

import '../Device/footer.dart';
import '../Device/tap_hint.dart';
import '../Device/gps_info.dart';
import '../Device/header.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => _buildCard();

  Widget _buildCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeviceHeader(
                device: device,
                onEdit: onEdit,
                onToggleStatus: onToggleStatus,
              ),
              const SizedBox(height: 12),
              DeviceGPSInfo(device: device),
              const SizedBox(height: 8),
              DeviceFooter(device: device),
              const SizedBox(height: 8),
              const DeviceTapHint(),
            ],
          ),
        ),
      ),
    );
  }
}

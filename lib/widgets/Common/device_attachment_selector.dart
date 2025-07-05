import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../services/device/deviceService.dart';

/// Reusable widget for handling device attachment/detachment with real-time UI feedback
/// while deferring database updates until confirmation.
class DeviceAttachmentSelector extends StatefulWidget {
  final String? currentDeviceId;
  final String? currentVehicleId;
  final Function(String deviceId) onDeviceSelected;
  final Function() onDeviceUnselected;
  final DeviceService deviceService;
  final bool showHeader;
  final String emptyStateMessage;

  const DeviceAttachmentSelector({
    Key? key,
    this.currentDeviceId,
    this.currentVehicleId,
    required this.onDeviceSelected,
    required this.onDeviceUnselected,
    required this.deviceService,
    this.showHeader = true,
    this.emptyStateMessage = 'No devices available',
  }) : super(key: key);

  @override
  State<DeviceAttachmentSelector> createState() =>
      _DeviceAttachmentSelectorState();
}

class _DeviceAttachmentSelectorState extends State<DeviceAttachmentSelector> {
  String _selectedDeviceId = '';
  String? _originalDeviceId;

  @override
  void initState() {
    super.initState();
    _selectedDeviceId = widget.currentDeviceId ?? '';
    _originalDeviceId = widget.currentDeviceId;
  }

  @override
  void didUpdateWidget(DeviceAttachmentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDeviceId != widget.currentDeviceId) {
      _selectedDeviceId = widget.currentDeviceId ?? '';
      _originalDeviceId = widget.currentDeviceId;
    }
  }

  bool _hasDeviceChanges() {
    return _selectedDeviceId != (_originalDeviceId ?? '');
  }

  void _handleDeviceSelection(String deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
    });
    widget.onDeviceSelected(deviceId);
  }

  void _handleDeviceUnselection() {
    setState(() {
      _selectedDeviceId = '';
    });
    widget.onDeviceUnselected();
  }

  void _resetChanges() {
    setState(() {
      _selectedDeviceId = _originalDeviceId ?? '';
    });
    if (_originalDeviceId?.isNotEmpty == true) {
      widget.onDeviceSelected(_originalDeviceId!);
    } else {
      widget.onDeviceUnselected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Device>>(
      stream: widget.deviceService.getDevicesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final devices = snapshot.data ?? [];

        if (devices.isEmpty) {
          return _buildEmptyState();
        }

        // Separate devices: those with vehicles vs those without
        final attachedDevices =
            devices
                .where(
                  (device) =>
                      device.vehicleId != null && device.vehicleId!.isNotEmpty,
                )
                .toList();
        final unattachedDevices =
            devices
                .where(
                  (device) =>
                      (device.vehicleId == null || device.vehicleId!.isEmpty) &&
                      device.id != _selectedDeviceId,
                )
                .toList();

        // Filter attached devices to only show those attached to OTHER vehicles
        final devicesAttachedToOthers =
            attachedDevices
                .where((device) => device.vehicleId != widget.currentVehicleId)
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Device Assignment
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add section header for clarity
                Text(
                  'Device Assignment',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),

                // Device Info
                if (_selectedDeviceId.isNotEmpty)
                  _buildCurrentDeviceInfo(_selectedDeviceId, devices)
                else
                  _buildNoDeviceAssigned(),

                // Contextual change banner
                if (_hasDeviceChanges()) ...[
                  const SizedBox(height: 12),
                  _buildChangesBanner(),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Available Devices
            if (unattachedDevices.isNotEmpty) ...[
              Text(
                'Available Devices',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              // Clean list without outer container
              ...unattachedDevices.map(
                (device) => _buildAvailableDeviceItem(device),
              ),
              const SizedBox(height: 16),
            ],

            // Attached Devices (other vehicles) - Only show if any exist
            if (devicesAttachedToOthers.isNotEmpty) ...[
              Text(
                'Devices Attached to Other Vehicles',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              // Clean list without outer container - consistent with available devices
              ...devicesAttachedToOthers.map(
                (device) => _buildAttachedDeviceItem(device),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error loading devices: $error',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 60,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.device_hub_rounded, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Text(
                widget.emptyStateMessage,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to device management - could be passed as callback
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add New Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDeviceInfo(String deviceId, List<Device> devices) {
    final device = devices.firstWhere(
      (d) => d.id == deviceId,
      orElse:
          () => Device(
            id: deviceId,
            name: 'Unknown Device',
            ownerId: '',
            isActive: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          // Device Icon with walking person to match the screenshot
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_walk,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 6),

                // Status Chip - Clean design
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ASSIGNED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Unassign Button - Clean design matching screenshot
          IconButton(
            onPressed: _handleDeviceUnselection,
            icon: const Icon(Icons.link_off, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            tooltip: 'Unassign Device',
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceAssigned() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          // Empty State Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.device_unknown,
              color: Colors.grey.shade400,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Empty State Message
          Text(
            'No Device Assigned',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a device from the available options below',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeviceItem(Device device) {
    final isSelected = _selectedDeviceId == device.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green.shade400 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Row(
        children: [
          // Device Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_walk,
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color:
                        isSelected
                            ? Colors.green.shade900
                            : Colors.grey.shade800,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 6),
                  // Status - only show when selected
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'SELECTED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Select Button
          _buildSelectButton(device),
        ],
      ),
    );
  }

  Widget _buildSelectButton(Device device) {
    final willAttach = _selectedDeviceId == device.id;

    return ElevatedButton(
      onPressed: () => _handleDeviceSelection(device.id),
      style: ElevatedButton.styleFrom(
        backgroundColor: willAttach ? Colors.green.shade600 : Colors.white,
        foregroundColor: willAttach ? Colors.white : Colors.grey.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        side: BorderSide(
          color: willAttach ? Colors.green.shade600 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        willAttach ? 'Selected' : 'Select',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildAttachedDeviceItem(Device device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          // Device Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_walk,
              color: Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),

                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ATTACHED TO OTHER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Read Only Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Read Only',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build contextual changes banner
  Widget _buildChangesBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_notifications,
              color: Colors.amber.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Assignment Changed',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Changes will be saved when you update the vehicle',
                  style: TextStyle(color: Colors.amber.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _resetChanges,
            icon: const Icon(Icons.undo),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            tooltip: 'Undo changes',
          ),
        ],
      ),
    );
  }
}

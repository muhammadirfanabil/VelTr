import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../services/device/deviceService.dart';
import '../GeoFence/index.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({Key? key}) : super(key: key);

  @override
  _DeviceManagerScreenState createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final DeviceService _deviceService = DeviceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Devices'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: StreamBuilder<List<Device>>(
          stream: _deviceService.getDevicesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final devices = snapshot.data ?? [];
            return devices.isEmpty
                ? _buildEmptyState()
                : _buildDeviceList(devices);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildErrorState(String error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
        const SizedBox(height: 16),
        Text('Error: $error', style: TextStyle(color: Colors.red.shade600)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() {}),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.devices_other, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'No GPS devices found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your first device to get started',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showAddDeviceDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Device'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildDeviceList(List<Device> devices) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: devices.length,
    itemBuilder: (context, index) {
      final device = devices[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: Key(device.id),
          direction: DismissDirection.endToStart,
          background: _buildDismissBackground(),
          confirmDismiss: (_) => _showDeleteConfirmation(device),
          onDismissed: (_) => _deleteDevice(device.id),
          child: DeviceCard(
            device: device,
            onTap: () => _navigateToGeofence(device),
            onEdit: () => _showEditDeviceDialog(device),
            onToggleStatus: () => _toggleDeviceStatus(device),
          ),
        ),
      );
    },
  );

  Widget _buildDismissBackground() => Container(
    decoration: BoxDecoration(
      color: Colors.red.shade400,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.delete, color: Colors.white, size: 28),
        SizedBox(height: 4),
      ],
    ),
  );

  void _navigateToGeofence(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceListScreen(deviceId: device.id),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Device device) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('Delete Device'),
                content: Text(
                  'Are you sure you want to delete ${device.name}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Colors.black, // Set the color of the text to black
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showAddDeviceDialog() => _showDeviceDialog();

  void _showEditDeviceDialog(Device device) =>
      _showDeviceDialog(device: device);

  void _showDeviceDialog({Device? device}) {
    final nameController = TextEditingController(text: device?.name ?? '');
    final isEdit = device != null;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEdit ? 'Edit Device' : 'Add New GPS Device'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: isEdit ? null : 'e.g., GPS Tracker 1',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    isEdit ? _updateDevice(device!, name) : _addDevice(name);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _addDevice(String name) async {
    try {
      await _deviceService.addDevice(name: name);
      if (mounted)
        _showSnackBar('Device "$name" added successfully', Colors.green);
    } catch (e) {
      if (mounted) _showSnackBar('Error adding device: $e', Colors.red);
    }
  }

  Future<void> _updateDevice(Device device, String newName) async {
    try {
      await _deviceService.updateDevice(device.copyWith(name: newName));
      if (mounted) _showSnackBar('Device renamed to "$newName"', Colors.green);
    } catch (e) {
      if (mounted) _showSnackBar('Error updating device: $e', Colors.red);
    }
  }

  Future<void> _deleteDevice(String id) async {
    try {
      await _deviceService.deleteDevice(id);
      if (mounted) _showSnackBar('Device deleted successfully', Colors.green);
    } catch (e) {
      if (mounted) _showSnackBar('Error deleting device: $e', Colors.red);
    }
  }

  Future<void> _toggleDeviceStatus(Device device) async {
    try {
      await _deviceService.toggleDeviceStatus(device.id, !device.isActive);
      if (mounted) {
        _showSnackBar(
          'Device ${device.isActive ? 'deactivated' : 'activated'} successfully',
          Colors.green,
        );
      }
    } catch (e) {
      if (mounted)
        _showSnackBar('Error updating device status: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
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
              _buildHeader(),
              const SizedBox(height: 12),
              _buildGPSInfo(),
              const SizedBox(height: 8),
              _buildFooter(),
              const SizedBox(height: 8),
              _buildTapHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: device.isActive ? Colors.green.shade100 : Colors.red.shade100,
        ),
        child: Icon(
          Icons.devices,
          color: device.isActive ? Colors.green : Colors.red,
          size: 24,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildStatusIndicator(),
          ],
        ),
      ),
      _buildActionButtons(),
    ],
  );

  Widget _buildStatusIndicator() => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: device.isActive ? Colors.green : Colors.red,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        device.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: device.isActive ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _buildActionButtons() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(
          device.isActive ? Icons.pause : Icons.play_arrow,
          color: device.isActive ? Colors.blueGrey.shade300 : Colors.green,
        ),
        onPressed: onToggleStatus,
        tooltip: device.isActive ? 'Deactivate' : 'Activate',
      ),
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.lightBlue),
        onPressed: onEdit,
        tooltip: 'Edit',
      ),
    ],
  );

  Widget _buildGPSInfo() => Container(
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

  Widget _buildFooter() => Row(
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

  Widget _buildTapHint() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.blue.shade200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app, size: 14, color: Colors.blue.shade700),
        const SizedBox(width: 4),
        Text(
          'Tap to view geofences',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  String _formatDate(DateTime dateTime) =>
      '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}

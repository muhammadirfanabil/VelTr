import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/device/device_card.dart';
import '../../widgets/Common/error_card.dart';
import '../../constants/app_constants.dart';
import '../../utils/snackbar.dart';
import '../GeoFence/index.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final DeviceService _deviceService = DeviceService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: _buildAppBar(theme, colorScheme),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed:
            () => Navigator.pushReplacementNamed(
              context,
              AppConstants.trackVehicleRoute,
            ),
      ),
      title: Text(
        'Device Manager',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showAddDeviceDialog,
          tooltip: 'Add Device',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.2)],
        ),
      ),
      child: StreamBuilder<List<Device>>(
        stream: _deviceService.getDevicesStream(),
        builder: _buildStreamBuilder,
      ),
    );
  }

  Widget _buildStreamBuilder(
    BuildContext context,
    AsyncSnapshot<List<Device>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ErrorCard(
            message: 'Failed to load devices: ${snapshot.error}',
            onRetry: () => setState(() {}),
          ),
        ),
      );
    }

    final devices = snapshot.data ?? [];
    return devices.isEmpty ? _buildEmptyState() : _buildDeviceList(devices);
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No GPS devices found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first device to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(List<Device> devices) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) => _buildDeviceItem(devices[index]),
    );
  }

  Widget _buildDeviceItem(Device device) {
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
  }

  Widget _buildDismissBackground() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 226, 46, 46),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: colorScheme.onError, size: 28),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: TextStyle(
              color: colorScheme.onError,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Device device) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Device'),
            content: Text(
              'Are you sure you want to delete "${device.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 226, 46, 46),
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  void _navigateToGeofence(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceListScreen(deviceId: device.id),
      ),
    );
  }

  void _showAddDeviceDialog() => _showDeviceDialog();

  void _showEditDeviceDialog(Device device) =>
      _showDeviceDialog(device: device);

  void _showDeviceDialog({Device? device}) {
    final nameController = TextEditingController(text: device?.name ?? '');
    final isEdit = device != null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isEdit ? 'Edit Device' : 'Add New GPS Device'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  hintText: isEdit ? null : 'e.g., GPS Tracker 1',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.devices),
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a device name';
                  }
                  if (value.trim().length < 2) {
                    return 'Device name must be at least 2 characters';
                  }
                  return null;
                },
                onFieldSubmitted:
                    (_) => _handleDeviceSubmission(
                      formKey,
                      nameController,
                      device,
                      isEdit,
                    ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => _handleDeviceSubmission(
                      formKey,
                      nameController,
                      device,
                      isEdit,
                    ),
                child: Text(isEdit ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  void _handleDeviceSubmission(
    GlobalKey<FormState> formKey,
    TextEditingController nameController,
    Device? device,
    bool isEdit,
  ) {
    if (formKey.currentState!.validate()) {
      final name = nameController.text.trim();
      if (isEdit && device != null) {
        _updateDevice(device, name);
      } else {
        _addDevice(name);
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _addDevice(String name) async {
    try {
      await _deviceService.addDevice(name: name);
      if (mounted) {
        _showSuccessSnackbar('Device "$name" added successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error adding device: $e');
      }
    }
  }

  Future<void> _updateDevice(Device device, String newName) async {
    try {
      await _deviceService.updateDevice(device.copyWith(name: newName));
      if (mounted) {
        _showSuccessSnackbar('Device renamed to "$newName"');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error updating device: $e');
      }
    }
  }

  Future<void> _deleteDevice(String id) async {
    try {
      await _deviceService.deleteDevice(id);
      if (mounted) {
        _showSuccessSnackbar('Device deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error deleting device: $e');
      }
    }
  }

  Future<void> _toggleDeviceStatus(Device device) async {
    try {
      await _deviceService.toggleDeviceStatus(device.id, !device.isActive);
      if (mounted) {
        final action = device.isActive ? 'deactivated' : 'activated';
        _showSuccessSnackbar('Device $action successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error updating device status: $e');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackbarUtils.showSuccess(context, message));
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackbarUtils.showError(context, message));
  }
}

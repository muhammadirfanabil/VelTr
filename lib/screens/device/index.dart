import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/Common/error_card.dart';
import '../../constants/app_constants.dart';
import '../../utils/snackbar.dart';
import '../GeoFence/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

// Use the official DeviceCard widget
import '../../widgets/Device/device_card.dart';

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

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: _buildBody(),
      backgroundColor: AppColors.backgroundPrimary,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.backgroundPrimary,
      leading: IconButton(
        icon: Icon(AppIcons.back, size: 20, color: AppColors.primaryBlue),
        onPressed:
            () => Navigator.pushReplacementNamed(
              context,
              AppConstants.trackVehicleRoute,
            ),
        tooltip: "Back",
      ),
      title: Text(
        'Device Manager',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 21,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(AppIcons.add, color: AppColors.primaryBlue),
          onPressed: _showAddDeviceDialog,
          tooltip: 'Add Device',
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: AppColors.primaryBlue),
          onPressed: () => setState(() {}),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundPrimary,
            AppColors.backgroundSecondary.withOpacity(0.98),
          ],
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
    if (devices.isEmpty) {
      return _buildEmptyState();
    }
    return _buildDeviceList(devices);
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: AppColors.primaryBlue.withOpacity(0.15),
            ),
            const SizedBox(height: 22),
            Text(
              'No GPS devices found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first device to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Device'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(List<Device> devices) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 36),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildDeviceItem(devices[index]),
    );
  }

  Widget _buildDeviceItem(Device device) {
    return Material(
      color: Colors.transparent,
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          const Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(Device device) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: Colors.orange[700],
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Delete Device',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "${device.name}"? This action cannot be undone.',
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                ),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Device' : 'Add New GPS Device',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  hintText: isEdit ? null : 'e.g., GPS Tracker 1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.devices),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    SnackbarUtils.showSuccess(context, message);
  }

  void _showErrorSnackbar(String message) {
    SnackbarUtils.showError(context, message);
  }
}

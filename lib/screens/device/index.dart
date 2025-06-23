import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/Common/error_card.dart';
import '../../constants/app_constants.dart';
import '../../utils/snackbar.dart';
import '../GeoFence/index.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

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
        icon: Icon(AppIcons.back, size: 20),
        onPressed:
            () => Navigator.pushReplacementNamed(
              context,
              AppConstants.trackVehicleRoute,
            ),
      ),
      title: Text(
        'Device Manager',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: true,
      backgroundColor: AppColors.backgroundPrimary,
      actions: [
        IconButton(
          icon: Icon(AppIcons.add),
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
          colors: [AppColors.backgroundPrimary, AppColors.backgroundSecondary],
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

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback? onLinkToVehicle; // New callback for linking

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    this.onLinkToVehicle, // Optional callback
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: AppColors.textTertiary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.surface,
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
              if (device.vehicleId == null || device.vehicleId!.isEmpty) ...[
                const SizedBox(height: 8),
                _buildLinkToVehicleButton(),
              ],
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
          device.isActive ? AppIcons.inactive : AppIcons.active,
          color: device.isActive ? AppColors.textSecondary : AppColors.success,
        ),
        onPressed: onToggleStatus,
        tooltip: device.isActive ? 'Deactivate' : 'Activate',
      ),
      IconButton(
        icon: Icon(AppIcons.edit, color: AppColors.info),
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
      color: AppColors.infoLight,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.info.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.location, size: 14, color: AppColors.infoText),
        const SizedBox(width: 4),
        Text(
          'Tap to view geofences',
          style: TextStyle(
            color: AppColors.infoText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _buildLinkToVehicleButton() {
    if (onLinkToVehicle == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onLinkToVehicle,
        icon: Icon(AppIcons.vehicle, size: 18),
        label: const Text('Link Device to Vehicle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: AppColors.backgroundPrimary,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) =>
      '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
}

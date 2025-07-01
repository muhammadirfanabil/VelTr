import 'package:flutter/material.dart';

import '../../models/vehicle/vehicle.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../services/device/deviceService.dart';
import '../../models/Device/device.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_colors.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Vehicle/vehicle_card.dart';
import '../../widgets/Common/confirmation_dialog.dart';
import '../../utils/snackbar.dart';

class ManageVehicle extends StatefulWidget {
  const ManageVehicle({Key? key}) : super(key: key);

  @override
  _ManageVehicleState createState() => _ManageVehicleState();
}

class _ManageVehicleState extends State<ManageVehicle> {
  final VehicleService _vehicleService = VehicleService();
  final DeviceService _deviceService = DeviceService();
  String _selectedDeviceId = '';

  Future<void> _addVehicle(
    String name,
    String vehicleTypes,
    String plateNumber,
    String deviceId,
  ) async {
    if (name.trim().isEmpty) {
      _showSnackBar(
        'Please enter a vehicle name',
        Colors.orange,
        Icons.warning_rounded,
      );
      return;
    }

    try {
      final vehicle = await _vehicleService.addVehicle(
        name: name.trim(),
        vehicleTypes: vehicleTypes.trim().isEmpty ? null : vehicleTypes.trim(),
        plateNumber: plateNumber.trim().isEmpty ? null : plateNumber.trim(),
        deviceId: deviceId.trim().isEmpty ? null : deviceId.trim(),
      );

      if (deviceId.trim().isNotEmpty) {
        await _deviceService.assignDeviceToVehicle(deviceId.trim(), vehicle.id);
        await _vehicleService.updateVehicle(
          vehicle.copyWith(deviceId: deviceId.trim()),
        );
      }

      _showSnackBar(
        '${name.trim()} added successfully',
        Colors.green,
        Icons.check_circle_rounded,
      );
    } catch (e) {
      _showSnackBar(
        'Error adding vehicle: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Future<void> _updateVehicle(
    String id,
    String name,
    String vehicleTypes,
    String plateNumber,
    String deviceId,
  ) async {
    if (name.trim().isEmpty) {
      _showSnackBar(
        'Please enter a vehicle name',
        Colors.orange,
        Icons.warning_rounded,
      );
      return;
    }

    try {
      final originalVehicle = await _vehicleService.getVehicleById(id);
      if (originalVehicle == null) throw Exception('Vehicle not found');

      final updatedVehicle = originalVehicle.copyWith(
        name: name.trim(),
        vehicleTypes: vehicleTypes.trim().isEmpty ? null : vehicleTypes.trim(),
        plateNumber: plateNumber.trim().isEmpty ? null : plateNumber.trim(),
        deviceId: deviceId.trim().isEmpty ? null : deviceId.trim(),
        updatedAt: DateTime.now(),
      );

      if (originalVehicle.deviceId != deviceId.trim()) {
        if (originalVehicle.deviceId?.isNotEmpty == true) {
          await _deviceService.unassignDeviceFromVehicle(
            originalVehicle.deviceId!,
          );
        }
        if (deviceId.trim().isNotEmpty) {
          await _deviceService.assignDeviceToVehicle(deviceId.trim(), id);
        }
      }

      await _vehicleService.updateVehicle(updatedVehicle);
      _showSnackBar(
        '${name.trim()} updated successfully',
        Colors.green,
        Icons.check_circle_rounded,
      );
    } catch (e) {
      _showSnackBar(
        'Error updating vehicle: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Widget _buildDeviceDropdown({
    String? currentValue,
    String? currentVehicleId,
  }) {
    return StreamBuilder<List<Device>>(
      stream: _deviceService.getDevicesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
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
                    'Error loading devices: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 60,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final devices = snapshot.data ?? [];

        if (currentValue != null &&
            !devices.any((device) => device.id == currentValue)) {
          _handleUnavailableDevice(currentValue);
        }

        if (devices.isEmpty) {
          return _buildEmptyDeviceContainer();
        }

        // Separate devices: those with vehicles vs those without
        final devicesWithVehicles =
            devices
                .where(
                  (device) =>
                      device.vehicleId != null && device.vehicleId!.isNotEmpty,
                )
                .toList();
        final devicesWithoutVehicles =
            devices
                .where(
                  (device) =>
                      device.vehicleId == null || device.vehicleId!.isEmpty,
                )
                .toList();

        // Build dropdown items
        List<DropdownMenuItem<String>> dropdownItems = [];

        // Add devices that are already linked to vehicles
        for (final device in devicesWithVehicles) {
          dropdownItems.add(
            _buildLinkedDeviceDropdownItem(device, currentVehicleId),
          );
        }
        // Add unlinked devices with "Attach to Vehicle" label
        for (final device in devicesWithoutVehicles) {
          dropdownItems.add(_buildUnlinkedDeviceDropdownItem(device));
        }

        // If no items available, return empty container message
        if (dropdownItems.isEmpty) {
          return _buildEmptyDeviceContainer();
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 56,
            maxHeight: 300, // Prevent dropdown from growing too large
          ),
          child: DropdownButtonFormField<String>(
            value: currentValue,
            decoration: _buildInputDecoration(
              'Device',
              Icons.device_hub_rounded,
            ),
            items: dropdownItems,
            isExpanded: true,
            dropdownColor: Colors.white,
            iconSize: 24,
            onChanged: (value) {
              try {
                if (value != null && value.startsWith('attach_')) {
                  final deviceId = value.substring('attach_'.length);
                  _handleAttachToVehicle(deviceId);
                } else if (value != null && value.isNotEmpty) {
                  final isValidDevice = devicesWithVehicles.any(
                    (device) => device.id == value,
                  );

                  if (isValidDevice) {
                    setState(() => _selectedDeviceId = value);
                  } else {
                    setState(() => _selectedDeviceId = '');
                  }
                } else {
                  setState(() => _selectedDeviceId = '');
                }
              } catch (e) {
                setState(() => _selectedDeviceId = '');
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _handleUnavailableDevice(String deviceId) async {
    try {
      final exists = await _vehicleService.verifyDeviceAvailability(deviceId);
      if (!exists && mounted) {
        setState(() => _selectedDeviceId = '');
        _showSnackBar(
          'Previously assigned device is no longer available',
          Colors.orange,
          Icons.warning_rounded,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Error verifying device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Container _buildEmptyDeviceContainer() {
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
                'No devices available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/device'),
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

  DropdownMenuItem<String> _buildLinkedDeviceDropdownItem(
    Device device,
    String? currentVehicleId,
  ) {
    if (device.vehicleId == null || device.vehicleId!.isEmpty) {
      return DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
          child: Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: Text(
              '${device.name} (No Vehicle Link)',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    final isAssignedToCurrentVehicle = device.vehicleId == currentVehicleId;
    final isAssignedToOtherVehicle =
        device.vehicleId != null &&
        device.vehicleId!.isNotEmpty &&
        device.vehicleId != currentVehicleId;

    String displayText = device.name;
    if (device.isActive) {
      displayText += ' (Active)';
    } else {
      displayText += ' (Inactive)';
    }

    if (isAssignedToOtherVehicle) {
      displayText += ' - Assigned to other vehicle';
    }
    return DropdownMenuItem<String>(
      value: device.id,
      enabled: isAssignedToCurrentVehicle || !isAssignedToOtherVehicle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
        child: Container(
          width: double.infinity,
          alignment: Alignment.centerLeft,
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 16,
              color:
                  isAssignedToOtherVehicle
                      ? Colors.grey.shade400
                      : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildUnlinkedDeviceDropdownItem(Device device) {
    if (device.vehicleId != null && device.vehicleId!.isNotEmpty) {
      return DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
          child: Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: Text(
              '${device.name} (Already Linked)',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    String displayText = '${device.name} - Attach to Vehicle';

    return DropdownMenuItem<String>(
      value: 'attach_${device.id}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 56),
        child: Container(
          width: double.infinity,
          child: Row(
            children: [
              Icon(Icons.link, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAttachToVehicle(String deviceId) async {
    try {
      final vehicleStream = _vehicleService.getVehiclesStream();
      final vehicles = await vehicleStream.first;

      if (vehicles.isEmpty) {
        _showNoVehiclesDialog();
      } else {
        Navigator.pushNamed(context, '/device/edit', arguments: deviceId);
      }
    } catch (e) {
      _showSnackBar(
        'Error checking vehicles: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  void _showNoVehiclesDialog() {
    ConfirmationDialog.show(
      context: context,
      title: 'No Vehicles Available',
      content:
          'You need to add a vehicle before you can attach this device. Would you like to add a vehicle now?',
      confirmText: 'Add Vehicle',
      cancelText: 'Cancel',
      confirmColor: Theme.of(context).colorScheme.primary,
    ).then((confirmed) {
      if (confirmed == true) {
        Navigator.pushNamed(context, '/vehicle');
      }
    });
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(AppIcons.back, size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/vehicle'),
        ),
        title: Text(
          'Manage Vehicles',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                alpha: 0.05,
              ), // Subtle background
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              onPressed: () => _showAddVehicleDialog(context),
              tooltip: 'Add Vehicle',
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<vehicle>>(
        stream: _vehicleService.getVehiclesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VehicleCard(
                    vehicleModel: vehicle,
                    onEdit: () => _showEditVehicleDialog(context, vehicle),
                    onDelete: () => _deleteVehicle(vehicle.id),
                    deviceService: _deviceService,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Loading vehicles...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ErrorCard(
          message: 'Something went wrong\n\nError: $error',
          onRetry: () => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                size: 64,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Vehicles Yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first vehicle to start tracking',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddVehicleDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Vehicle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context) {
    final controllers = _createControllers();
    _selectedDeviceId = '';

    showDialog(
      context: context,
      builder:
          (context) => _buildVehicleDialog(
            context: context,
            title: 'Add New Vehicle',
            icon: Icons.add_circle_rounded,
            iconColor: Colors.blue,
            controllers: controllers,
            onConfirm: () {
              _addVehicle(
                controllers[0].text,
                controllers[1].text,
                controllers[2].text,
                _selectedDeviceId,
              );
              Navigator.pop(context);
            },
            confirmText: 'Add Vehicle',
            confirmColor: Colors.blue,
            currentDeviceId: null,
            currentVehicleId: null,
          ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, vehicle vehicle) {
    final controllers = _createControllers(
      name: vehicle.name,
      type: vehicle.vehicleTypes ?? '',
      plate: vehicle.plateNumber ?? '',
    );
    _selectedDeviceId = vehicle.deviceId ?? '';

    showDialog(
      context: context,
      builder:
          (context) => _buildVehicleDialog(
            context: context,
            title: 'Edit Vehicle',
            icon: Icons.edit_rounded,
            iconColor: Colors.orange,
            controllers: controllers,
            onConfirm: () {
              _updateVehicle(
                vehicle.id,
                controllers[0].text,
                controllers[1].text,
                controllers[2].text,
                _selectedDeviceId,
              );
              Navigator.pop(context);
            },
            confirmText: 'Update',
            confirmColor: Colors.orange,
            currentDeviceId: vehicle.deviceId,
            currentVehicleId: vehicle.id,
          ),
    );
  }

  List<TextEditingController> _createControllers({
    String? name,
    String? type,
    String? plate,
  }) {
    return [
      TextEditingController(text: name),
      TextEditingController(text: type),
      TextEditingController(text: plate),
    ];
  }

  Widget _buildVehicleDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<TextEditingController> controllers,
    required VoidCallback onConfirm,
    required String confirmText,
    required Color confirmColor,
    required String? currentDeviceId,
    required String? currentVehicleId,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              controllers[0],
              'Vehicle Name',
              'e.g., Toyota Camry 2023',
              Icons.directions_car_rounded,
              true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controllers[1],
              'Vehicle Type',
              'e.g., Sedan, SUV, Truck',
              Icons.category_rounded,
              false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controllers[2],
              'License Plate',
              'e.g., ABC-1234',
              Icons.confirmation_number_rounded,
              false,
            ),
            const SizedBox(height: 16),
            _buildDeviceDropdown(
              currentValue: currentDeviceId,
              currentVehicleId: currentVehicleId,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    bool isRequired,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Future<void> _deleteVehicle(String id) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Vehicle',
      content:
          'Are you sure you want to delete this vehicle? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await _vehicleService.deleteVehicle(id);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Vehicle deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error deleting vehicle: $e');
      }
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    if (color == Colors.red) {
      SnackbarUtils.showError(context, message);
    } else if (color == Colors.green) {
      SnackbarUtils.showSuccess(context, message);
    } else if (color == Colors.orange) {
      SnackbarUtils.showWarning(context, message);
    } else {
      SnackbarUtils.showInfo(context, message);
    }
  }
}

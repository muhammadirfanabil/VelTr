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
        await _vehicleService.assignDevice(deviceId.trim(), vehicle.id);
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
      debugPrint('🔧 [DEVICE_ASSIGN] Starting device assignment process');
      final originalVehicle = await _vehicleService.getVehicleById(id);
      if (originalVehicle == null) throw Exception('Vehicle not found');

      debugPrint(
        '🔧 [DEVICE_ASSIGN] Original vehicle deviceId: ${originalVehicle.deviceId}',
      );
      debugPrint('🔧 [DEVICE_ASSIGN] New deviceId: ${deviceId.trim()}');

      final updatedVehicle = originalVehicle.copyWith(
        name: name.trim(),
        vehicleTypes: vehicleTypes.trim().isEmpty ? null : vehicleTypes.trim(),
        plateNumber: plateNumber.trim().isEmpty ? null : plateNumber.trim(),
        deviceId: deviceId.trim().isEmpty ? null : deviceId.trim(),
        updatedAt: DateTime.now(),
      );

      if (originalVehicle.deviceId != deviceId.trim()) {
        debugPrint('🔧 [DEVICE_ASSIGN] Device assignment change detected');

        if (originalVehicle.deviceId?.isNotEmpty == true) {
          debugPrint(
            '🔧 [DEVICE_ASSIGN] Unassigning old device: ${originalVehicle.deviceId}',
          );
          await _vehicleService.unassignDevice(
            originalVehicle.deviceId!,
            originalVehicle.id,
          );
          debugPrint('✅ [DEVICE_ASSIGN] Old device unassigned successfully');
        }

        if (deviceId.trim().isNotEmpty) {
          debugPrint(
            '🔧 [DEVICE_ASSIGN] Assigning new device: ${deviceId.trim()} to vehicle: $id',
          );
          await _vehicleService.assignDevice(deviceId.trim(), id);
          debugPrint('✅ [DEVICE_ASSIGN] New device assigned successfully');
        }
      } else {
        debugPrint('🔧 [DEVICE_ASSIGN] No device assignment change');
      }

      debugPrint('🔧 [DEVICE_ASSIGN] Updating vehicle in Firestore');
      await _vehicleService.updateVehicle(updatedVehicle);
      debugPrint('✅ [DEVICE_ASSIGN] Vehicle updated successfully');

      _showSnackBar(
        '${name.trim()} updated successfully',
        Colors.green,
        Icons.check_circle_rounded,
      );
    } catch (e) {
      debugPrint('❌ [DEVICE_ASSIGN] Error updating vehicle: $e');
      _showSnackBar(
        'Error updating vehicle: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Widget _buildDeviceSection({String? currentValue, String? currentVehicleId}) {
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

        if (devices.isEmpty) {
          return _buildEmptyDeviceContainer();
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
                      device.vehicleId == null || device.vehicleId!.isEmpty,
                )
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Device Assignment
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.device_hub_rounded,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Device Assignment',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentValue != null && currentValue.isNotEmpty)
                    _buildCurrentDeviceInfo(
                      currentValue,
                      devices,
                      currentVehicleId,
                    )
                  else
                    _buildNoDeviceAssigned(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Available Devices
            if (unattachedDevices.isNotEmpty) ...[
              Text(
                'Available Devices',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children:
                      unattachedDevices
                          .map((device) => _buildAvailableDeviceItem(device))
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Attached Devices (other vehicles)
            if (attachedDevices.isNotEmpty) ...[
              Text(
                'Devices Attached to Other Vehicles',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children:
                      attachedDevices
                          .where(
                            (device) => device.vehicleId != currentVehicleId,
                          )
                          .map((device) => _buildAttachedDeviceItem(device))
                          .toList(),
                ),
              ),
            ],
          ],
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
      print(
        '🔧 [DEBUG] _handleAttachToVehicle called with deviceId: $deviceId',
      );
      final vehicleStream = _vehicleService.getVehiclesStream();
      final vehicles = await vehicleStream.first;

      if (vehicles.isEmpty) {
        print('🔧 [DEBUG] No vehicles found, showing no vehicles dialog');
        _showNoVehiclesDialog();
      } else {
        print(
          '🔧 [DEBUG] Found ${vehicles.length} vehicles, showing selection dialog',
        );
        _showVehicleSelectionDialog(deviceId, vehicles);
      }
    } catch (e) {
      print('🔧 [ERROR] Error in _handleAttachToVehicle: $e');
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

  void _showVehicleSelectionDialog(String deviceId, List<vehicle> vehicles) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.link_rounded, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text('Attach Device to Vehicle'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a vehicle to attach this device to:',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  // List of vehicles
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicles[index];
                        final hasDevice =
                            vehicle.deviceId != null &&
                            vehicle.deviceId!.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  hasDevice ? Colors.orange : Colors.green,
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              vehicle.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (vehicle.plateNumber != null &&
                                    vehicle.plateNumber!.isNotEmpty)
                                  Text('Plate: ${vehicle.plateNumber}'),
                                if (hasDevice)
                                  Flexible(
                                    child: Text(
                                      'Current device: ${vehicle.deviceId}',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                else
                                  Text(
                                    'No device attached',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Icon(
                              hasDevice
                                  ? Icons.warning_rounded
                                  : Icons.check_circle_rounded,
                              color: hasDevice ? Colors.orange : Colors.green,
                            ),
                            onTap:
                                () =>
                                    _confirmDeviceAttachment(deviceId, vehicle),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _confirmDeviceAttachment(String deviceId, vehicle targetVehicle) {
    final hasExistingDevice =
        targetVehicle.deviceId != null && targetVehicle.deviceId!.isNotEmpty;

    final title = hasExistingDevice ? 'Replace Device?' : 'Attach Device?';
    final content =
        hasExistingDevice
            ? 'Vehicle "${targetVehicle.name}" already has device "${targetVehicle.deviceId}" attached. Do you want to replace it with this device?'
            : 'Are you sure you want to attach this device to vehicle "${targetVehicle.name}"?';

    ConfirmationDialog.show(
      context: context,
      title: title,
      content: content,
      confirmText: hasExistingDevice ? 'Replace' : 'Attach',
      cancelText: 'Cancel',
      confirmColor: hasExistingDevice ? Colors.orange : Colors.blue,
    ).then((confirmed) {
      if (confirmed == true) {
        _performDeviceAttachment(deviceId, targetVehicle);
      }
    });
  }

  void _performDeviceAttachment(String deviceId, vehicle targetVehicle) async {
    try {
      print(
        '🔧 [DEBUG] Starting device attachment: deviceId=$deviceId, vehicleId=${targetVehicle.id}, vehicleName=${targetVehicle.name}',
      );

      // First, close the vehicle selection dialog
      Navigator.pop(context);

      // Show loading indicator
      _showSnackBar(
        'Attaching device to ${targetVehicle.name}...',
        Colors.blue,
        Icons.link_rounded,
      );

      // If target vehicle already has a device, unassign it first
      if (targetVehicle.deviceId != null &&
          targetVehicle.deviceId!.isNotEmpty) {
        print(
          '🔧 [DEBUG] Target vehicle has existing device ${targetVehicle.deviceId}, unassigning first',
        );
        await _vehicleService.unassignDevice(
          targetVehicle.deviceId!,
          targetVehicle.id,
        );
      }

      // Assign the new device to the target vehicle
      print(
        '🔧 [DEBUG] Assigning device $deviceId to vehicle ${targetVehicle.id}',
      );
      await _vehicleService.assignDevice(deviceId, targetVehicle.id);

      print('🔧 [DEBUG] Device attachment completed successfully');
      _showSnackBar(
        'Device successfully attached to ${targetVehicle.name}',
        Colors.green,
        Icons.check_circle_rounded,
      );

      // Refresh the UI
      setState(() {});
    } catch (e) {
      print('🔧 [ERROR] Error during device attachment: $e');
      _showSnackBar(
        'Failed to attach device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  void _handleAttachDeviceInForm(String deviceId) async {
    try {
      print(
        '🔧 [DEBUG] _handleAttachDeviceInForm called with deviceId: $deviceId',
      );

      // Show confirmation
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Attach Device',
        content:
            'Are you sure you want to attach this device to the current vehicle?',
        confirmText: 'Attach',
        cancelText: 'Cancel',
        confirmColor: Colors.green,
      );

      if (confirmed == true) {
        print('🔧 [DEBUG] User confirmed attach, setting device in form');

        // Update the selected device ID in the form
        setState(() {
          _selectedDeviceId = deviceId;
        });

        print('🔧 [DEBUG] Device attached in form successfully');

        _showSnackBar(
          'Device selected for attachment',
          Colors.green,
          Icons.check_circle_rounded,
        );
      } else {
        print('🔧 [DEBUG] User cancelled attach');
      }
    } catch (e) {
      print('🔧 [ERROR] Error in _handleAttachDeviceInForm: $e');
      _showSnackBar(
        'Error attaching device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
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
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
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
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final vehicle = vehicles[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VehicleCard(
                          vehicleModel: vehicle,
                          onEdit:
                              () => _showEditVehicleDialog(context, vehicle),
                          onDelete: () => _deleteVehicle(vehicle.id),
                          deviceService: _deviceService,
                        ),
                      );
                    }, childCount: vehicles.length),
                  ),
                ),
              ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // No Vehicles Section
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
              color: iconColor.withValues(alpha: 0.1),
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
            _buildDeviceSection(
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

  Widget _buildUnattachedDevicesSection() {
    return StreamBuilder<List<Device>>(
      stream: _deviceService.getDevicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.device_hub_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Unattached Devices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.device_hub_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Unattached Devices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ErrorCard(
                  message: 'Error loading devices: ${snapshot.error}',
                  onRetry: () => setState(() {}),
                ),
              ],
            ),
          );
        }

        final devices = snapshot.data ?? [];
        final unattachedDevices =
            devices
                .where(
                  (device) =>
                      device.vehicleId == null || device.vehicleId!.isEmpty,
                )
                .toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.device_hub_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Unattached Devices',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${unattachedDevices.length}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (unattachedDevices.isEmpty)
                _buildNoUnattachedDevicesWidget()
              else
                ...unattachedDevices.map(
                  (device) => _buildUnattachedDeviceCard(device),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoUnattachedDevicesWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Devices Attached',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your devices are currently attached to vehicles',
            style: TextStyle(fontSize: 14, color: Colors.green.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/device'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add New Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnattachedDeviceCard(Device device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.device_hub_rounded,
              color: Colors.orange.shade600,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      device.isActive ? Icons.circle : Icons.circle_outlined,
                      color: device.isActive ? Colors.green : Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        color: device.isActive ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'UNATTACHED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _handleAttachToVehicle(device.id),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Attach'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDeviceInfo(
    String deviceId,
    List<Device> devices,
    String? vehicleId,
  ) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        children: [
          Icon(
            device.isActive ? Icons.device_hub : Icons.device_hub_outlined,
            color:
                device.isActive ? Colors.green.shade600 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            device.isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        device.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              device.isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ASSIGNED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _handleUnattachFromVehicle(deviceId, vehicleId),
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('Unattach'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceAssigned() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.device_hub_outlined,
            color: Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No device currently assigned to this vehicle',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeviceItem(Device device) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(
            device.isActive ? Icons.device_hub : Icons.device_hub_outlined,
            color:
                device.isActive ? Colors.green.shade600 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            device.isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        device.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              device.isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'AVAILABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _handleAttachDeviceInForm(device.id),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Attach'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedDeviceItem(Device device) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            device.isActive ? Icons.device_hub : Icons.device_hub_outlined,
            color:
                device.isActive ? Colors.green.shade600 : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            device.isActive
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        device.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              device.isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ATTACHED TO OTHER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Read Only',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleUnattachFromVehicle(String deviceId, String? vehicleId) async {
    try {
      print(
        '🔧 [DEBUG] _handleUnattachFromVehicle called with deviceId: $deviceId, vehicleId: $vehicleId',
      );

      if (vehicleId == null || vehicleId.isEmpty) {
        print('❌ [DEBUG] Vehicle ID is null or empty, cannot unattach');
        _showSnackBar(
          'Cannot unattach device: Vehicle ID not available',
          Colors.red,
          Icons.error_rounded,
        );
        return;
      }

      // Show confirmation dialog
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Unattach Device',
        content:
            'Are you sure you want to unattach this device from the vehicle? The device will become available for other vehicles.',
        confirmText: 'Unattach',
        cancelText: 'Cancel',
        confirmColor: Colors.red,
      );

      if (confirmed == true) {
        print('🔧 [DEBUG] User confirmed unattach, proceeding...');

        await _vehicleService.unassignDevice(deviceId, vehicleId);

        // Update the selected device ID in the form
        setState(() {
          _selectedDeviceId = '';
        });

        print('🔧 [DEBUG] Device unattached successfully');

        _showSnackBar(
          'Device unattached successfully',
          Colors.green,
          Icons.check_circle_rounded,
        );
      } else {
        print('🔧 [DEBUG] User cancelled unattach');
      }
    } catch (e) {
      print('🔧 [ERROR] Error in _handleUnattachFromVehicle: $e');
      _showSnackBar(
        'Error unattaching device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }
}

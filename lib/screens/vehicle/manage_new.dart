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

  // Temporary state for delayed persistence
  String _selectedDeviceId = '';
  String? _originalDeviceId; // Track original state for comparison

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

      // Handle device assignment changes first
      bool deviceAssignmentChanged =
          originalVehicle.deviceId != deviceId.trim();

      if (deviceAssignmentChanged) {
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
      }

      // Update vehicle information (excluding deviceId if assignment was handled above)
      debugPrint(
        '🔧 [DEVICE_ASSIGN] Updating vehicle information in Firestore',
      );
      if (deviceAssignmentChanged) {
        // If device assignment changed, don't update deviceId again to avoid conflicts
        // Create vehicle with updated info but preserve the deviceId that was set by assign/unassign
        final vehicleForUpdate = originalVehicle.copyWith(
          name: name.trim(),
          vehicleTypes:
              vehicleTypes.trim().isEmpty ? null : vehicleTypes.trim(),
          plateNumber: plateNumber.trim().isEmpty ? null : plateNumber.trim(),
          // Don't update deviceId here - it was already handled by assign/unassign methods
          updatedAt: DateTime.now(),
        );
        await _vehicleService.updateVehicleInfoOnly(vehicleForUpdate);
      } else {
        // No device assignment change, update normally
        await _vehicleService.updateVehicle(updatedVehicle);
      }
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
                      (device.vehicleId == null || device.vehicleId!.isEmpty) &&
                      device.id !=
                          _selectedDeviceId, // Exclude currently selected device
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
                  _buildDeviceAssignmentHeader(),
                  const SizedBox(height: 12),
                  if (_selectedDeviceId.isNotEmpty)
                    _buildCurrentDeviceInfo(
                      _selectedDeviceId,
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
                  color: AppColors.warningDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningLight),
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

  // ENHANCED UI/UX: Device attachment with delayed persistence
  void _handleAttachDeviceInForm(String deviceId) async {
    try {
      debugPrint(
        '🚀 [DEBUG] _handleAttachDeviceInForm called with deviceId: $deviceId',
      );
      debugPrint(
        '🚀 [DEBUG] Current _selectedDeviceId before: $_selectedDeviceId',
      );
      debugPrint('🚀 [DEBUG] Current _originalDeviceId: $_originalDeviceId');

      // Update UI state immediately for instant feedback
      setState(() {
        _selectedDeviceId = deviceId;
      });

      debugPrint(
        '🚀 [DEBUG] _selectedDeviceId after setState: $_selectedDeviceId',
      );
      debugPrint('🚀 [DEBUG] Device selected in form (temporary state)');

      _showSnackBar(
        'Device selected for attachment. Click "Update" to save changes.',
        Colors.blue,
        Icons.info_rounded,
      );
    } catch (e) {
      debugPrint('🚀 [ERROR] Error in _handleAttachDeviceInForm: $e');
      _showSnackBar(
        'Error selecting device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  void _handleUnattachFromVehicle(String deviceId, String? vehicleId) async {
    try {
      debugPrint(
        '🚀 [DEBUG] _handleUnattachFromVehicle called with deviceId: $deviceId, vehicleId: $vehicleId',
      );
      debugPrint(
        '🚀 [DEBUG] Current _selectedDeviceId before: $_selectedDeviceId',
      );

      // Update UI state immediately for instant feedback
      setState(() {
        _selectedDeviceId = '';
      });

      debugPrint(
        '🚀 [DEBUG] _selectedDeviceId after setState: $_selectedDeviceId',
      );
      debugPrint('🚀 [DEBUG] Device unselected from form (temporary state)');

      _showSnackBar(
        'Device unselected. Click "Update" to save changes.',
        Colors.blue,
        Icons.info_rounded,
      );
    } catch (e) {
      debugPrint('🚀 [ERROR] Error in _handleUnattachFromVehicle: $e');
      _showSnackBar(
        'Error unselecting device: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  /// Reset temporary changes back to original state
  void _resetDeviceChanges() {
    setState(() {
      _selectedDeviceId = _originalDeviceId ?? '';
    });

    _showSnackBar(
      'Changes reverted to original state.',
      Colors.orange,
      Icons.undo_rounded,
    );
  }

  /// Check if the current device selection differs from original
  bool _hasDeviceChanges() {
    final hasChanges = _selectedDeviceId != (_originalDeviceId ?? '');
    debugPrint(
      '🚀 [DEBUG] _hasDeviceChanges: selected=$_selectedDeviceId, original=$_originalDeviceId, hasChanges=$hasChanges',
    );
    return hasChanges;
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
    // Reset temporary state for new vehicle
    _selectedDeviceId = '';
    _originalDeviceId = null;

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
    // Set up temporary state for editing
    _selectedDeviceId = vehicle.deviceId ?? '';
    _originalDeviceId = vehicle.deviceId;

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
        _buildUpdateButton(
          onConfirm: onConfirm,
          confirmText: confirmText,
          confirmColor: confirmColor,
          currentDeviceId: currentDeviceId,
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

  // ENHANCED UI/UX: Current device info with visual feedback
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

    final hasChanges = _hasDeviceChanges();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasChanges ? Colors.orange.shade300 : Colors.blue.shade300,
          width: hasChanges ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Device Info Row
          Row(
            children: [
              Icon(
                device.isActive ? Icons.device_hub : Icons.device_hub_outlined,
                color:
                    device.isActive
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
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
                            color:
                                hasChanges
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasChanges ? 'PENDING' : 'ASSIGNED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  hasChanges
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  if (hasChanges)
                    ElevatedButton.icon(
                      onPressed: _resetDeviceChanges,
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Undo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (hasChanges) const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed:
                        () => _handleUnattachFromVehicle(deviceId, vehicleId),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Pending Changes Indicator
          if (hasChanges) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Device assignment changed. Click "Update" to save.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ENHANCED UI/UX: No device assigned with visual feedback
  Widget _buildNoDeviceAssigned() {
    final hasChanges = _hasDeviceChanges();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasChanges ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasChanges ? Colors.orange.shade300 : Colors.grey.shade300,
          width: hasChanges ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.device_hub_outlined,
                color:
                    hasChanges ? Colors.orange.shade600 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasChanges
                      ? 'Device will be removed when you click "Update"'
                      : 'No device currently assigned to this vehicle',
                  style: TextStyle(
                    color:
                        hasChanges
                            ? Colors.orange.shade700
                            : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight:
                        hasChanges ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              if (hasChanges)
                ElevatedButton.icon(
                  onPressed: _resetDeviceChanges,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Undo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (hasChanges) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Device will be unassigned. Click "Update" to save changes.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ENHANCED UI/UX: Available device with selection feedback
  Widget _buildAvailableDeviceItem(Device device) {
    final isSelected = _selectedDeviceId == device.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange.shade400 : Colors.green.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.2),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
                : null,
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
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontStyle: isSelected ? FontStyle.italic : FontStyle.normal,
                    color: isSelected ? Colors.orange.shade800 : Colors.black,
                  ),
                  child: Text(device.name),
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            isSelected
                                ? Border.all(
                                  color: Colors.orange.shade300,
                                  width: 1,
                                )
                                : null,
                      ),
                      child: Text(
                        isSelected ? 'SELECTED' : 'AVAILABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildSelectButton(device),
        ],
      ),
    );
  }

  // ENHANCED UI/UX: Smart select button with state feedback
  Widget _buildSelectButton(Device device) {
    final willAttach = _selectedDeviceId == device.id;
    debugPrint(
      '🚀 [DEBUG] _buildSelectButton for device ${device.id}: willAttach=$willAttach, _selectedDeviceId=$_selectedDeviceId',
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton.icon(
        onPressed: () {
          debugPrint(
            '🚀 [DEBUG] Select button pressed for device: ${device.id}',
          );
          _handleAttachDeviceInForm(device.id);
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            willAttach ? Icons.check_circle_rounded : Icons.add_rounded,
            size: 18,
            key: ValueKey(willAttach),
          ),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            willAttach ? 'Selected' : 'Select',
            key: ValueKey(willAttach),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              willAttach ? Colors.orange.shade600 : Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: willAttach ? FontWeight.bold : FontWeight.w600,
          ),
          elevation: willAttach ? 6 : 2,
          shadowColor:
              willAttach
                  ? Colors.orange.withValues(alpha: 0.5)
                  : Colors.green.withValues(alpha: 0.3),
        ),
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
            // child: Text(
            //   'Read Only',
            //   style: TextStyle(
            //     fontSize: 12,
            //     color: Colors.grey.shade600,
            //     fontWeight: FontWeight.w500,
            //   ),
            // ),
          ),
        ],
      ),
    );
  }

  // ENHANCED UI/UX: Dynamic update button with prominent feedback
  Widget _buildUpdateButton({
    required VoidCallback onConfirm,
    required String confirmText,
    required Color confirmColor,
    required String? currentDeviceId,
  }) {
    final hasChanges = _hasDeviceChanges();
    final baseColor = hasChanges ? Colors.orange : confirmColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pulsing effect for pending changes
          if (hasChanges)
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(
                          alpha: 0.3 * (1 - value),
                        ),
                        blurRadius: 15 * value,
                        spreadRadius: 3 * value,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              onEnd: () {
                // Loop the animation
                if (mounted && hasChanges) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) setState(() {});
                  });
                }
              },
              child: Container(width: 0, height: 0), // Invisible placeholder
            ),
          // Main button with enhanced styling when changes are pending
          Container(
            decoration:
                hasChanges
                    ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                    : null,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: baseColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                elevation: hasChanges ? 8 : 2,
                shadowColor:
                    hasChanges ? Colors.orange.withValues(alpha: 0.5) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasChanges) ...[
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.save_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    confirmText,
                    style: TextStyle(
                      fontWeight:
                          hasChanges ? FontWeight.bold : FontWeight.w600,
                      fontSize: hasChanges ? 16 : 14,
                      letterSpacing: hasChanges ? 0.5 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Badge indicator for pending changes
          if (hasChanges)
            Positioned(
              top: -6,
              right: -6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ENHANCED UI/UX: Dynamic header with pending change indicators
  Widget _buildDeviceAssignmentHeader() {
    final hasChanges = _hasDeviceChanges();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Row(
        children: [
          // Icon with animation and color change
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(4),
            decoration:
                hasChanges
                    ? BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    )
                    : null,
            child: Icon(
              hasChanges
                  ? Icons
                      .device_hub_outlined // Different icon when changes pending
                  : Icons.device_hub_rounded,
              color: hasChanges ? Colors.orange.shade600 : Colors.blue.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          // Title with dynamic styling
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: hasChanges ? Colors.orange.shade700 : Colors.blue.shade700,
              fontStyle: hasChanges ? FontStyle.italic : FontStyle.normal,
            ),
            child: const Text('Device Assignment'),
          ),
          // Pending changes indicator
          if (hasChanges) ...[
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MODIFIED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

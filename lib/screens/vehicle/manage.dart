import 'package:flutter/material.dart';

import '../../models/vehicle/vehicle.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../services/device/deviceService.dart';
import '../../models/Device/device.dart';

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
        } // Add unlinked devices with "Attach to Vehicle" label
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
            isExpanded: true, // Allow text to use full width
            dropdownColor: Colors.white,
            iconSize: 24,
            onChanged: (value) {
              try {
                if (value != null && value.startsWith('attach_')) {
                  // Handle "Attach to Vehicle" action for unlinked devices
                  final deviceId = value.substring('attach_'.length);
                  _handleAttachToVehicle(deviceId);
                } else if (value != null && value.isNotEmpty) {
                  // Simple validation: just check if the value is in our devices list
                  final isValidDevice = devicesWithVehicles.any(
                    (device) => device.id == value,
                  );

                  if (isValidDevice) {
                    print('Device selected: $value');
                    setState(() => _selectedDeviceId = value);
                  } else {
                    print('Invalid device selection: $value');
                    setState(() => _selectedDeviceId = '');
                  }
                } else {
                  // Clear selection
                  setState(() => _selectedDeviceId = '');
                }
              } catch (e) {
                print('Error in device selection: $e');
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
      // Check if device still exists
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
      debugPrint('Error checking device availability: $e');
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

  /// Build dropdown item for devices that are already linked to vehicles
  DropdownMenuItem<String> _buildLinkedDeviceDropdownItem(
    Device device,
    String? currentVehicleId,
  ) {
    // Safety check: only build item if device has a vehicleId
    if (device.vehicleId == null || device.vehicleId!.isEmpty) {
      // Return a disabled item as fallback instead of throwing
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

    // A device is available if it's assigned to the current vehicle being edited
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

  /// Build dropdown item for devices that are not linked to any vehicle
  DropdownMenuItem<String> _buildUnlinkedDeviceDropdownItem(Device device) {
    // Safety check: ensure device truly has no vehicleId
    if (device.vehicleId != null && device.vehicleId!.isNotEmpty) {
      // Return a disabled item as fallback instead of throwing
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
      value: 'attach_${device.id}', // Use 'attach_' prefix for unlinked devices
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

  /// Handle the "Attach to Vehicle" action
  void _handleAttachToVehicle(String deviceId) async {
    try {
      // Check if any vehicles exist
      final vehicleStream = _vehicleService.getVehiclesStream();
      final vehicles = await vehicleStream.first;

      if (vehicles.isEmpty) {
        _showNoVehiclesDialog();
      } else {
        // Navigate to device edit page or show vehicle selector
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

  /// Show dialog when no vehicles are available for attachment
  void _showNoVehiclesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No Vehicles Available'),
            content: const Text(
              'You need to add a vehicle before you can attach this device. '
              'Would you like to add a vehicle now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/vehicle');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Vehicle'),
              ),
            ],
          ),
    );
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
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

          return ListView.builder(
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicleDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Vehicle'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Manage Vehicles',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(() {}),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
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
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
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
            Text(
              'No vehicles yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first vehicle to start tracking\nand managing your fleet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddVehicleDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Vehicle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
            showDeviceDropdown: true,
            currentDeviceId: null,
            currentVehicleId: null, // New vehicle has no ID yet
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
            showDeviceDropdown: true,
            currentDeviceId: vehicle.deviceId,
            currentVehicleId:
                vehicle.id, // Pass the vehicle ID for proper filtering
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
    bool showDeviceDropdown = true,
    String? currentDeviceId,
    String? currentVehicleId,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
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
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: IntrinsicHeight(
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controllers[0],
                    'Vehicle Name',
                    'e.g., Toyota Camry 2023',
                    Icons.directions_car_rounded,
                    true,
                    TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controllers[1],
                    'Vehicle Type',
                    'e.g., Sedan, SUV, Truck',
                    Icons.category_rounded,
                    false,
                    TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controllers[2],
                    'License Plate',
                    'e.g., ABC-1234',
                    Icons.confirmation_number_rounded,
                    false,
                    TextCapitalization.characters,
                  ),
                  if (showDeviceDropdown) ...[
                    const SizedBox(height: 20),
                    _buildDeviceDropdown(
                      currentValue: currentDeviceId,
                      currentVehicleId: currentVehicleId,
                    ),
                  ],
                ],
              ),
            ),
          ),
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
    TextCapitalization textCapitalization,
  ) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      decoration: _buildInputDecoration(
        isRequired ? '$label *' : label,
        icon,
      ).copyWith(hintText: hint),
    );
  }

  Future<void> _deleteVehicle(String id) async {
    final confirmed = await _showDeleteConfirmation();
    if (confirmed != true) return;

    try {
      await _vehicleService.deleteVehicle(id);
      _showSnackBar(
        'Vehicle deleted successfully',
        Colors.green,
        Icons.check_circle_rounded,
      );
    } catch (e) {
      _showSnackBar(
        'Error deleting vehicle: $e',
        Colors.red,
        Icons.error_rounded,
      );
    }
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Confirm Deletion',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to delete this vehicle? This action cannot be undone.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
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
    );
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  final vehicle vehicleModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final DeviceService deviceService;

  const VehicleCard({
    Key? key,
    required this.vehicleModel,
    required this.onEdit,
    required this.onDelete,
    required this.deviceService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicleModel.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (vehicleModel.vehicleTypes != null)
                    _buildTag(
                      vehicleModel.vehicleTypes!,
                      Colors.blue,
                      Icons.category_rounded,
                    ),
                  if (vehicleModel.plateNumber != null)
                    _buildTag(
                      vehicleModel.plateNumber!,
                      Colors.green,
                      Icons.confirmation_number_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(
              Icons.edit_rounded,
              Colors.blue,
              onEdit,
              'Edit Vehicle',
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              Icons.delete_rounded,
              Colors.red,
              () => _showDeleteConfirmation(context),
              'Delete Vehicle',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (vehicleModel.deviceId != null) ...[
            StreamBuilder<Device?>(
              stream: deviceService.getDeviceStream(vehicleModel.deviceId!),
              builder: (context, snapshot) {
                // Only show device info if device exists and data is loaded
                if (snapshot.hasData && snapshot.data != null) {
                  return Column(
                    children: [
                      _buildInfoRow(
                        Icons.device_hub_rounded,
                        'Device ID',
                        vehicleModel.deviceId!,
                        Colors.purple,
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                return const SizedBox.shrink(); // Don't show anything if device doesn't exist
              },
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.calendar_today_rounded,
                  'Created',
                  _formatDate(vehicleModel.createdAt),
                  Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoRow(
                  Icons.update_rounded,
                  'Updated',
                  _formatDate(vehicleModel.updatedAt),
                  Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
    String tooltip,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete Vehicle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete ${vehicleModel.name}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}

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
  final vehicleService _vehicleService = vehicleService();
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

  Widget _buildDeviceDropdown({String? currentValue}) {
    return StreamBuilder<List<Device>>(
      stream: _deviceService.getDevicesStream(),
      builder: (context, snapshot) {
        // Add debug prints
        print('Device snapshot state: ${snapshot.connectionState}');
        print('Device snapshot hasError: ${snapshot.hasError}');
        print('Device snapshot error: ${snapshot.error}');
        print('Device snapshot data length: ${snapshot.data?.length ?? 0}');

        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final devices = snapshot.data ?? [];
        print('Available devices: ${devices.map((d) => d.name).toList()}');

        if (devices.isEmpty) {
          return _buildEmptyDeviceContainer();
        }

        return DropdownButtonFormField<String>(
          value: currentValue,
          decoration: _buildInputDecoration('Device', Icons.device_hub_rounded),
          items:
              devices
                  .map(
                    (device) => _buildDeviceDropdownItem(device, currentValue),
                  )
                  .toList(),
          onChanged: (value) {
            print('Device selected: $value');
            setState(() => _selectedDeviceId = value ?? '');
          },
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
      child: Row(
        children: [
          Icon(Icons.device_hub_rounded, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            'No devices available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildDeviceDropdownItem(
    Device device,
    String? currentValue,
  ) {
    final isAssignedToOther =
        device.vehicleId != null && device.vehicleId != currentValue;

    // Create a simple text representation
    String displayText = device.name;
    if (device.isActive) {
      displayText += ' (Active)';
    } else {
      displayText += ' (Inactive)';
    }
    if (isAssignedToOther) {
      displayText += ' - Assigned';
    }

    return DropdownMenuItem<String>(
      value: device.id,
      enabled: !isAssignedToOther,
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 16,
          color: isAssignedToOther ? Colors.grey.shade400 : Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Container _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color, // Changed from Colors.grey[400] to use the actual color
          fontWeight: FontWeight.w500,
        ),
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
            showDeviceDropdown: true, // This is crucial!
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
              _buildDeviceDropdown(currentValue: currentDeviceId),
            ],
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
            _buildInfoRow(
              Icons.device_hub_rounded,
              'Device ID',
              vehicleModel.deviceId!,
              Colors.purple,
            ),
            const SizedBox(height: 12),
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

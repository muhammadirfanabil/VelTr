import 'package:flutter/material.dart';
// import 'package:gps_app/models/Vehicle/Vehicle.dart' as VehicleModel;

import '../../models/vehicle/vehicle.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../services/device/deviceService.dart';
import '../../models/Device/device.dart';

class VehicleIndexScreen extends StatefulWidget {
  const VehicleIndexScreen({Key? key}) : super(key: key);

  @override
  _VehicleIndexScreenState createState() => _VehicleIndexScreenState();
}

class _VehicleIndexScreenState extends State<VehicleIndexScreen> {
  final vehicleService _vehicleService = vehicleService();
  final DeviceService _deviceService = DeviceService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<vehicle>>(
        stream: _vehicleService.getVehiclesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final vehicles = snapshot.data ?? [];

          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No vehicles found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddVehicleDialog(context),
                    child: const Text('Add your first vehicle'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];              return VehicleCard(
                vehicleModel: vehicle,
                onEdit: () => _showEditVehicleDialog(context, vehicle),
                onDelete: () => _deleteVehicle(vehicle.id),
                onManageDevice: () => _showDeviceManagementDialog(context, vehicle),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final vehicleTypesController = TextEditingController();
    final plateNumberController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New vehicle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (Make & Model)',
                    ),
                  ),
                  TextField(
                    controller: vehicleTypesController,
                    decoration: const InputDecoration(
                      labelText: 'vehicle Type',
                    ),
                  ),
                  TextField(
                    controller: plateNumberController,
                    decoration: const InputDecoration(
                      labelText: 'License Plate',
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
              TextButton(
                onPressed: () {
                  _addVehicle(
                    nameController.text,
                    vehicleTypesController.text,
                    plateNumberController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showEditVehicleDialog(BuildContext context, vehicle vehicle) {
    final nameController = TextEditingController(text: vehicle.name);
    final vehicleTypesController = TextEditingController(
      text: vehicle.vehicleTypes,
    );
    final plateNumberController = TextEditingController(
      text: vehicle.plateNumber,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit vehicle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (Make & Model)',
                    ),
                  ),
                  TextField(
                    controller: vehicleTypesController,
                    decoration: const InputDecoration(
                      labelText: 'vehicle Type',
                    ),
                  ),
                  TextField(
                    controller: plateNumberController,
                    decoration: const InputDecoration(
                      labelText: 'License Plate',
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
              TextButton(
                onPressed: () {
                  _updateVehicle(
                    vehicle.id,
                    nameController.text,
                    vehicleTypesController.text,
                    plateNumberController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _addVehicle(String name, String vehicleTypes, String plateNumber) async {
    if (name.isEmpty || vehicleTypes.isEmpty || plateNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      await _vehicleService.addVehicle(
        name: name,
        vehicleTypes: vehicleTypes,
        plateNumber: plateNumber,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('vehicle added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding vehicle: $e')));
    }
  }
  void _updateVehicle(
    String id,
    String name,
    String vehicleTypes,
    String plateNumber,
  ) async {
    try {
      final existingVehicle = await _vehicleService.getVehicleById(id);
      if (existingVehicle != null) {
        final updatedVehicle = existingVehicle.copyWith(
          name: name,
          vehicleTypes: vehicleTypes,
          plateNumber: plateNumber,
        );
        await _vehicleService.updateVehicle(updatedVehicle);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('vehicle updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating vehicle: $e')));
    }
  }
  void _deleteVehicle(String id) async {
    try {
      await _vehicleService.deleteVehicle(id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('vehicle deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting vehicle: $e')));
    }
  }

  void _showDeviceManagementDialog(BuildContext context, vehicle vehicle) async {
    // Get current device assigned to this vehicle
    Device? currentDevice;
    if (vehicle.deviceId != null) {
      currentDevice = await _deviceService.getDeviceById(vehicle.deviceId!);
    }

    // Get list of unassigned devices
    final unassignedDevices = await _deviceService.getUnassignedDevices();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Device for ${vehicle.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Device:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                if (currentDevice != null)
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: Icon(Icons.gps_fixed, color: Colors.green),
                      title: Text(currentDevice.name),
                      subtitle: Text(
                        currentDevice.hasValidGPS 
                          ? 'GPS: ${currentDevice.coordinatesString}'
                          : 'No GPS data',
                      ),
                      trailing: Icon(
                        currentDevice.isActive ? Icons.signal_cellular_4_bar : Icons.signal_cellular_off,
                        color: currentDevice.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  )
                else
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: Icon(Icons.gps_off, color: Colors.orange),
                      title: Text('No device assigned'),
                      subtitle: Text('This vehicle has no GPS tracker'),
                    ),
                  ),
                SizedBox(height: 16),
                Text(
                  'Available Devices:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                if (unassignedDevices.isEmpty)
                  Text(
                    'No unassigned devices available',
                    style: TextStyle(color: Colors.grey),
                  )                else
                  ...unassignedDevices.map((device) => Card(
                    child: ListTile(
                      leading: Icon(Icons.device_hub),
                      title: Text(device.name),
                      subtitle: Text(
                        device.hasValidGPS 
                          ? 'GPS: ${device.coordinatesString}'
                          : 'No GPS data',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.link, color: Colors.blue),
                        onPressed: () async {
                          await _assignDeviceToVehicle(vehicle.id, device.id);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  )).toList(),
                SizedBox(height: 16),
                Text(
                  'Device Actions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddDeviceDialog(context, vehicle);
                        },
                        icon: Icon(Icons.add),
                        label: Text('Create New Device'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (unassignedDevices.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAttachExistingDeviceDialog(context, vehicle);
                          },
                          icon: Icon(Icons.link),
                          label: Text('Attach Existing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (currentDevice != null)
              TextButton(
                onPressed: () async {
                  await _unassignDeviceFromVehicle(vehicle.id);
                  Navigator.pop(context);
                },
                child: Text('Unassign Device', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddDeviceDialog(context, vehicle);
              },
              child: Text('Add New Device'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignDeviceToVehicle(String vehicleId, String deviceId) async {
    try {
      await _vehicleService.attachDeviceToVehicle(vehicleId, deviceId);
      await _deviceService.assignDeviceToVehicle(deviceId, vehicleId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device assigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning device: $e')),
      );
    }
  }

  Future<void> _unassignDeviceFromVehicle(String vehicleId) async {
    try {
      // Get the vehicle to find the device ID
      final vehicleData = await _vehicleService.getVehicleById(vehicleId);
      if (vehicleData?.deviceId != null) {
        await _deviceService.unassignDeviceFromVehicle(vehicleData!.deviceId!);
      }
      await _vehicleService.detachDeviceFromVehicle(vehicleId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device unassigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unassigning device: $e')),
      );
    }
  }

  void _showAddDeviceDialog(BuildContext context, vehicle vehicle) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Device for ${vehicle.name}'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Device Name',
            hintText: 'e.g., GPS Tracker 1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a device name')),
                );
                return;
              }

              try {
                final device = await _deviceService.addDevice(
                  name: nameController.text.trim(),
                  vehicleId: vehicle.id,
                );
                
                await _vehicleService.attachDeviceToVehicle(vehicle.id, device.id);
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Device created and assigned successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating device: $e')),
                );
              }
            },
            child: Text('Create & Assign'),
          ),
        ],
      ),    );
  }

  void _showAttachExistingDeviceDialog(BuildContext context, vehicle vehicle) async {
    final unassignedDevices = await _deviceService.getUnassignedDevices();

    if (!mounted) return;

    if (unassignedDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No unassigned devices available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attach Device to ${vehicle.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a device to attach:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...unassignedDevices.map((device) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.device_hub,
                    color: device.isActive ? Colors.green : Colors.orange,
                  ),
                  title: Text(device.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: device.isActive ? Colors.green : Colors.orange,
                        ),
                      ),
                      if (device.hasValidGPS)
                        Text('GPS: ${device.coordinatesString}')
                      else
                        Text('No GPS data', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () async {
                      await _assignDeviceToVehicle(vehicle.id, device.id);
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.link, size: 16),
                    label: Text('Attach'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  final vehicle vehicleModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageDevice;

  const VehicleCard({
    Key? key,
    required this.vehicleModel,
    required this.onEdit,
    required this.onDelete,
    required this.onManageDevice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vehicleModel.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.device_hub,
                        color: vehicleModel.deviceId != null ? Colors.green : Colors.orange,
                      ),
                      onPressed: onManageDevice,
                      tooltip: vehicleModel.deviceId != null ? 'Manage Device' : 'Assign Device',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Delete ${vehicleModel.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onDelete();
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),            const SizedBox(height: 8),
            Text('Type: ${vehicleModel.vehicleTypes}'),
            Text('License Plate: ${vehicleModel.plateNumber}'),
            Row(
              children: [
                Icon(
                  vehicleModel.deviceId != null ? Icons.gps_fixed : Icons.gps_off,
                  size: 16,
                  color: vehicleModel.deviceId != null ? Colors.green : Colors.red,
                ),
                SizedBox(width: 4),
                Text(
                  vehicleModel.deviceId != null ? 'GPS Device Assigned' : 'No GPS Device',
                  style: TextStyle(
                    color: vehicleModel.deviceId != null ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text('Created: ${_formatDate(vehicleModel.createdAt)}'),
            Text('Last Updated: ${_formatDate(vehicleModel.updatedAt)}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';
import '../../services/vehicle/vehicleService.dart';

class DeviceIndexScreen extends StatefulWidget {
  const DeviceIndexScreen({Key? key}) : super(key: key);

  @override
  _DeviceIndexScreenState createState() => _DeviceIndexScreenState();
}

class _DeviceIndexScreenState extends State<DeviceIndexScreen> {
  final DeviceService _deviceService = DeviceService();
  final vehicleService _vehicleService = vehicleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<Device>>(
        stream: _deviceService.getDevicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final devices = snapshot.data ?? [];

          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No GPS devices found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showAddDeviceDialog(context),
                    child: const Text('Add your first device'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return DeviceCard(
                device: device,
                onEdit: () => _showEditDeviceDialog(context, device),
                onDelete: () => _deleteDevice(device.id),
                onToggleStatus: () => _toggleDeviceStatus(device),
                onManageVehicle:
                    () => _showVehicleAssignmentDialog(context, device),
                onUpdateGPS: () => _showGPSUpdateDialog(context, device),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDeviceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New GPS Device'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g., GPS Tracker 1',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    _addDevice(nameController.text.trim());
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showEditDeviceDialog(BuildContext context, Device device) {
    final nameController = TextEditingController(text: device.name);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Device'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Device Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    _updateDevice(device, nameController.text.trim());
                    Navigator.pop(context);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _showVehicleAssignmentDialog(BuildContext context, Device device) async {
    final vehicles = await _vehicleService.getVehiclesWithoutDevice();
    vehicle? currentVehicle;

    if (device.vehicleId != null) {
      currentVehicle = await _vehicleService.getVehicleById(device.vehicleId!);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Manage Vehicle for ${device.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentVehicle != null) ...[
                    Text(
                      'Currently assigned to:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Card(
                      color: Colors.green.shade50,
                      child: ListTile(
                        leading: Icon(
                          Icons.directions_car,
                          color: Colors.green,
                        ),
                        title: Text(currentVehicle.name),
                        subtitle: Text(
                          '${currentVehicle.vehicleTypes} • ${currentVehicle.plateNumber}',
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  Text(
                    'Available vehicles:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  if (vehicles.isEmpty)
                    Text(
                      'No vehicles available for assignment',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...vehicles
                        .map(
                          (vehicle) => Card(
                            child: ListTile(
                              leading: Icon(Icons.directions_car),
                              title: Text(vehicle.name),
                              subtitle: Text(
                                '${vehicle.vehicleTypes} • ${vehicle.plateNumber}',
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.link, color: Colors.blue),
                                onPressed: () async {
                                  await _assignDeviceToVehicle(
                                    device.id,
                                    vehicle.id,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                ],
              ),
            ),
            actions: [
              if (device.vehicleId != null)
                TextButton(
                  onPressed: () async {
                    await _unassignDeviceFromVehicle(device.id);
                    Navigator.pop(context);
                  },
                  child: Text('Unassign', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showGPSUpdateDialog(BuildContext context, Device device) {
    final latController = TextEditingController(
      text: device.gpsData?['latitude']?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: device.gpsData?['longitude']?.toString() ?? '',
    );
    final altController = TextEditingController(
      text: device.gpsData?['altitude']?.toString() ?? '',
    );
    final speedController = TextEditingController(
      text: device.gpsData?['speed']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Update GPS Data for ${device.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: latController,
                    decoration: InputDecoration(labelText: 'Latitude'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  TextField(
                    controller: lngController,
                    decoration: InputDecoration(labelText: 'Longitude'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  TextField(
                    controller: altController,
                    decoration: InputDecoration(
                      labelText: 'Altitude (optional)',
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  TextField(
                    controller: speedController,
                    decoration: InputDecoration(labelText: 'Speed (optional)'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final lat = double.tryParse(latController.text);
                  final lng = double.tryParse(lngController.text);

                  if (lat != null && lng != null) {
                    _updateDeviceGPS(
                      device.id,
                      lat,
                      lng,
                      double.tryParse(altController.text),
                      double.tryParse(speedController.text),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter valid latitude and longitude',
                        ),
                      ),
                    );
                  }
                },
                child: Text('Update'),
              ),
            ],
          ),
    );
  }

  void _addDevice(String name) async {
    try {
      await _deviceService.addDevice(name: name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding device: $e')));
    }
  }

  void _updateDevice(Device device, String newName) async {
    try {
      final updatedDevice = device.copyWith(name: newName);
      await _deviceService.updateDevice(updatedDevice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating device: $e')));
    }
  }

  void _deleteDevice(String id) async {
    try {
      await _deviceService.deleteDevice(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting device: $e')));
    }
  }

  void _toggleDeviceStatus(Device device) async {
    try {
      await _deviceService.toggleDeviceStatus(device.id, !device.isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Device ${device.isActive ? 'deactivated' : 'activated'} successfully',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating device status: $e')),
      );
    }
  }

  Future<void> _assignDeviceToVehicle(String deviceId, String vehicleId) async {
    try {
      await _deviceService.assignDeviceToVehicle(deviceId, vehicleId);
      await _vehicleService.attachDeviceToVehicle(vehicleId, deviceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device assigned to vehicle successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error assigning device: $e')));
    }
  }

  Future<void> _unassignDeviceFromVehicle(String deviceId) async {
    try {
      final device = await _deviceService.getDeviceById(deviceId);
      if (device?.vehicleId != null) {
        await _vehicleService.detachDeviceFromVehicle(device!.vehicleId!);
      }
      await _deviceService.unassignDeviceFromVehicle(deviceId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device unassigned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error unassigning device: $e')));
    }
  }

  void _updateDeviceGPS(
    String deviceId,
    double lat,
    double lng,
    double? alt,
    double? speed,
  ) async {
    try {
      await _deviceService.updateDeviceGPS(
        deviceId: deviceId,
        latitude: lat,
        longitude: lng,
        altitude: alt,
        speed: speed,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS data updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating GPS data: $e')));
    }
  }
}

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final VoidCallback onManageVehicle;
  final VoidCallback onUpdateGPS;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onManageVehicle,
    required this.onUpdateGPS,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            device.isActive
                                ? Icons.signal_cellular_4_bar
                                : Icons.signal_cellular_off,
                            size: 16,
                            color: device.isActive ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            device.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color:
                                  device.isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        device.isActive ? Icons.pause : Icons.play_arrow,
                        color: device.isActive ? Colors.orange : Colors.green,
                      ),
                      onPressed: onToggleStatus,
                      tooltip: device.isActive ? 'Deactivate' : 'Activate',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.directions_car,
                        color:
                            device.vehicleId != null
                                ? Colors.green
                                : Colors.orange,
                      ),
                      onPressed: onManageVehicle,
                      tooltip:
                          device.vehicleId != null
                              ? 'Manage Vehicle'
                              : 'Assign Vehicle',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.gps_fixed,
                        color: device.hasValidGPS ? Colors.green : Colors.grey,
                      ),
                      onPressed: onUpdateGPS,
                      tooltip: 'Update GPS',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Delete ${device.name}?'),
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
            ),
            const SizedBox(height: 8),
            if (device.vehicleId != null)
              FutureBuilder<vehicle?>(
                future: vehicleService().getVehicleById(device.vehicleId!),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final vehicle = snapshot.data!;
                    return Row(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 16,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text('Vehicle: ${vehicle.name}'),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 16,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 4),
                      Text('Loading vehicle info...'),
                    ],
                  );
                },
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text('No vehicle assigned'),
                ],
              ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  device.hasValidGPS ? Icons.gps_fixed : Icons.gps_off,
                  size: 16,
                  color: device.hasValidGPS ? Colors.green : Colors.red,
                ),
                SizedBox(width: 4),
                Text(
                  device.hasValidGPS
                      ? 'GPS: ${device.coordinatesString}'
                      : 'No GPS data',
                  style: TextStyle(
                    color: device.hasValidGPS ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text('Created: ${_formatDate(device.createdAt)}'),
            Text('Last Updated: ${_formatDate(device.updatedAt)}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import '../../models/Vehicle/Vehicle.dart';
import '../../services/Vehicle/VehicleService.dart';

class VehicleIndexScreen extends StatefulWidget {
  const VehicleIndexScreen({Key? key}) : super(key: key);

  @override
  _VehicleIndexScreenState createState() => _VehicleIndexScreenState();
}

class _VehicleIndexScreenState extends State<VehicleIndexScreen> {
  final VehicleService _vehicleService = VehicleService();
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
      body: StreamBuilder<List<Vehicle>>(
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
              final vehicle = vehicles[index];

              return VehicleCard(
                vehicle: vehicle,
                onEdit: () => _showEditVehicleDialog(context, vehicle),
                onDelete: () => _deleteVehicle(vehicle.id),
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
            title: const Text('Add New Vehicle'),
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
                      labelText: 'Vehicle Type',
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

  void _showEditVehicleDialog(BuildContext context, Vehicle vehicle) {
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
            title: const Text('Edit Vehicle'),
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
                      labelText: 'Vehicle Type',
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
        const SnackBar(content: Text('Vehicle added successfully')),
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
      await _vehicleService.updateVehicle(
        id: id,
        name: name,
        vehicleTypes: vehicleTypes,
        plateNumber: plateNumber,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle updated successfully')),
      );
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
        const SnackBar(content: Text('Vehicle deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting vehicle: $e')));
    }
  }
}

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VehicleCard({
    Key? key,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
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
                  vehicle.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Delete ${vehicle.name}?'),
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
            Text('Type: ${vehicle.vehicleTypes}'),
            Text('License Plate: ${vehicle.plateNumber}'),
            Text('Created: ${_formatDate(vehicle.createdAt)}'),
            Text('Last Updated: ${_formatDate(vehicle.updatedAt)}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}

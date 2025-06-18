import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/vehicle_selector.dart';
import '../providers/vehicle_provider.dart';

/// Example screen showing how to integrate the Vehicle Selector
class VehicleSelectorExampleScreen extends StatefulWidget {
  const VehicleSelectorExampleScreen({Key? key}) : super(key: key);

  @override
  State<VehicleSelectorExampleScreen> createState() =>
      _VehicleSelectorExampleScreenState();
}

class _VehicleSelectorExampleScreenState
    extends State<VehicleSelectorExampleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Vehicle Selector - Similar to "Dikirim ke" pattern
            VehicleSelector(
              title: 'Tracking Vehicle',
              emptyMessage: 'Select a vehicle to track',
              onVehicleChanged: () {
                // Called when vehicle selection changes
                _onVehicleChanged();
              },
            ),

            // Content based on selected vehicle
            Consumer<VehicleProvider>(
              builder: (context, vehicleProvider, child) {
                if (!vehicleProvider.hasSelectedVehicle) {
                  return _buildNoVehicleContent();
                }

                return _buildVehicleContent(vehicleProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVehicleContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Select a Vehicle',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a vehicle from the selector above to view its location, history, and manage geofences.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleContent(VehicleProvider vehicleProvider) {
    final vehicle = vehicleProvider.selectedVehicle!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Vehicle Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: Colors.green.shade600,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (vehicle.plateNumber != null)
                          Text(
                            vehicle.plateNumber!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (vehicle.deviceId != null)
                          Text(
                            'Device: ${vehicle.deviceId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          _buildActionButtons(vehicle),
        ],
      ),
    );
  }

  Widget _buildActionButtons(vehicle) {
    return Column(
      children: [
        // Map View Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/map',
                arguments: {'vehicleId': vehicle.id},
              );
            },
            icon: const Icon(Icons.map),
            label: const Text('View on Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // History Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/drive-history',
                arguments: vehicle.id,
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('Driving History'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Geofence Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/geofence',
                arguments: {'vehicleId': vehicle.id},
              );
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Manage Geofences'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onVehicleChanged() {
    // This method is called when the vehicle selection changes
    print('Vehicle selection changed');

    // You can trigger any data refresh here, for example:
    // - Refresh map location
    // - Update geofence data
    // - Clear cached data
    // - Update other UI components

    // Example: Show a snackbar
    final vehicleProvider = Provider.of<VehicleProvider>(
      context,
      listen: false,
    );
    if (vehicleProvider.hasSelectedVehicle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Now tracking: ${vehicleProvider.selectedVehicle!.name}',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }
}

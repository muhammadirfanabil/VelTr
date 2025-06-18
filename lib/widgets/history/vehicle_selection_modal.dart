import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';

class VehicleSelectionModal extends StatelessWidget {
  final List<vehicle> availableVehicles;
  final vehicle? selectedVehicle;
  final bool isLoadingVehicles;
  final Function(vehicle) onVehicleSelected;

  const VehicleSelectionModal({
    super.key,
    required this.availableVehicles,
    required this.selectedVehicle,
    required this.isLoadingVehicles,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Select Vehicle',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          // Vehicle list
          Expanded(
            child: isLoadingVehicles
                ? const Center(child: CircularProgressIndicator())
                : availableVehicles.isEmpty
                    ? _buildEmptyState()
                    : _buildVehicleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No vehicles found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: availableVehicles.length,
      itemBuilder: (context, index) {
        final vehicle = availableVehicles[index];
        final isSelected = selectedVehicle?.id == vehicle.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? Colors.blue[50] : Colors.white,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_car,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            title: Text(
              vehicle.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue[700] : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vehicle.plateNumber?.isNotEmpty == true)
                  Text(
                    'Plate: ${vehicle.plateNumber}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                if (vehicle.vehicleTypes?.isNotEmpty == true)
                  Text(
                    'Type: ${vehicle.vehicleTypes}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.blue[600])
                : null,
            onTap: () {
              onVehicleSelected(vehicle);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

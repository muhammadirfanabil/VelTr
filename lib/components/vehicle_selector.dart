import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle/vehicle.dart';
import '../providers/vehicle_provider.dart';

/// A reusable vehicle selector component similar to "Dikirim ke" pattern
class VehicleSelector extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final EdgeInsets? padding;
  final VoidCallback? onVehicleChanged;
  final bool showDeviceInfo;

  const VehicleSelector({
    Key? key,
    this.title = 'Select Vehicle',
    this.emptyMessage = 'No vehicle selected',
    this.padding,
    this.onVehicleChanged,
    this.showDeviceInfo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, child) {
        return Container(
          padding: padding ?? const EdgeInsets.all(16),
          child: _buildSelectorCard(context, vehicleProvider),
        );
      },
    );
  }

  Widget _buildSelectorCard(
    BuildContext context,
    VehicleProvider vehicleProvider,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showVehicleSelector(context, vehicleProvider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (vehicleProvider.selectedVehicle != null)
                      _buildSelectedVehicleInfo(
                        vehicleProvider.selectedVehicle!,
                      )
                    else
                      Text(
                        emptyMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedVehicleInfo(vehicle selectedVehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedVehicle.name,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (showDeviceInfo &&
            (selectedVehicle.plateNumber != null ||
                selectedVehicle.deviceId != null))
          const SizedBox(height: 2),
        if (showDeviceInfo && selectedVehicle.plateNumber != null)
          Text(
            selectedVehicle.plateNumber!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        if (showDeviceInfo && selectedVehicle.deviceId != null)
          Text(
            'Device: ${selectedVehicle.deviceId}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
      ],
    );
  }

  void _showVehicleSelector(
    BuildContext context,
    VehicleProvider vehicleProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => VehicleSelectorBottomSheet(
            vehicles: vehicleProvider.vehicles,
            selectedVehicle: vehicleProvider.selectedVehicle,
            onVehicleSelected: (vehicle) {
              vehicleProvider.selectVehicle(vehicle);
              Navigator.pop(context);
              onVehicleChanged?.call();
            },
            isLoading: vehicleProvider.isLoading,
            error: vehicleProvider.error,
          ),
    );
  }
}

/// Bottom sheet component for vehicle selection
class VehicleSelectorBottomSheet extends StatelessWidget {
  final List<vehicle> vehicles;
  final vehicle? selectedVehicle;
  final Function(vehicle) onVehicleSelected;
  final bool isLoading;
  final String? error;

  const VehicleSelectorBottomSheet({
    Key? key,
    required this.vehicles,
    required this.selectedVehicle,
    required this.onVehicleSelected,
    required this.isLoading,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Vehicle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  iconSize: 24,
                ),
              ],
            ),
          ),

          // Content
          Flexible(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error loading vehicles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No vehicles found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a vehicle to get started',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      itemCount: vehicles.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final isSelected = selectedVehicle?.id == vehicle.id;

        return ListTile(
          onTap: () => onVehicleSelected(vehicle),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_car,
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              size: 20,
            ),
          ),
          title: Text(
            vehicle.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.blue.shade800 : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vehicle.plateNumber != null)
                Text(
                  vehicle.plateNumber!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              if (vehicle.deviceId != null)
                Text(
                  'Device: ${vehicle.deviceId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
          trailing:
              isSelected
                  ? Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade600,
                    size: 20,
                  )
                  : null,
        );
      },
    );
  }
}

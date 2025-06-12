import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';

class VehicleSelectorBottomSheet extends StatelessWidget {
  final List<vehicle> vehicles;
  final bool isLoading;
  final String? currentDeviceId;
  final Function(String vehicleId, String vehicleName) onVehicleSelected;
  final DeviceService deviceService;

  const VehicleSelectorBottomSheet({
    Key? key,
    required this.vehicles,
    required this.isLoading,
    required this.currentDeviceId,
    required this.onVehicleSelected,
    required this.deviceService,
  }) : super(key: key);

  Future<bool> _isVehicleSelected(vehicle vehicleToCheck) async {
    if (vehicleToCheck.deviceId == null) return false;

    try {
      final deviceName = await deviceService.getDeviceNameById(
        vehicleToCheck.deviceId!,
      );
      return deviceName == currentDeviceId;
    } catch (e) {
      debugPrint('Error checking vehicle selection: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.directions_car, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Select Vehicle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vehicles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No vehicles available',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];

                  return FutureBuilder<bool>(
                    future: _isVehicleSelected(vehicle),
                    builder: (context, snapshot) {
                      final isSelected = snapshot.data ?? false;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.directions_car,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                        ),
                        title: Text(
                          vehicle.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color: isSelected ? Colors.blue : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (vehicle.plateNumber != null)
                              Text(
                                vehicle.plateNumber!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            if (vehicle.deviceId != null)
                              Text(
                                'Device: ${vehicle.deviceId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                )
                                : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey,
                                ),
                        onTap: () {
                          Navigator.pop(context);
                          if (!isSelected && vehicle.deviceId != null) {
                            onVehicleSelected(vehicle.deviceId!, vehicle.name);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

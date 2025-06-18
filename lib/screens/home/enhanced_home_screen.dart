import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/vehicle_selector.dart';
import '../providers/vehicle_provider.dart';

/// Enhanced Home Screen with Vehicle Selector Integration
/// This shows how to integrate the VehicleSelector component in your main app
class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'VelTr GPS',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Selector - Similar to "Dikirim ke" pattern
            Container(
              color: Colors.white,
              child: VehicleSelector(
                title: 'Current Vehicle',
                emptyMessage: 'Select a vehicle to track',
                padding: const EdgeInsets.all(16),
                onVehicleChanged: _onVehicleSelectionChanged,
              ),
            ),

            const SizedBox(height: 8),

            // Main Content based on selected vehicle
            Consumer<VehicleProvider>(
              builder: (context, vehicleProvider, child) {
                if (vehicleProvider.isLoading) {
                  return _buildLoadingContent();
                }

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

  Widget _buildLoadingContent() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading vehicles...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVehicleContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 48,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to VelTr GPS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a vehicle from the selector above to start tracking its location, view driving history, and manage geofences.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/manage-vehicle'),
            icon: const Icon(Icons.add),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
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

  Widget _buildVehicleContent(VehicleProvider vehicleProvider) {
    final vehicle = vehicleProvider.selectedVehicle!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Online',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),

          const SizedBox(height: 12),

          // Action Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildActionCard(
                icon: Icons.map,
                title: 'Live Map',
                subtitle: 'View real-time location',
                color: Colors.blue,
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      '/home',
                      arguments: {'vehicleId': vehicle.id},
                    ),
              ),
              _buildActionCard(
                icon: Icons.history,
                title: 'History',
                subtitle: 'View driving routes',
                color: Colors.orange,
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      '/drive-history',
                      arguments: {
                        'vehicleId': vehicle.id,
                        'vehicleName': vehicle.name,
                      },
                    ),
              ),
              _buildActionCard(
                icon: Icons.location_on,
                title: 'Geofences',
                subtitle: 'Manage zones',
                color: Colors.purple,
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      '/geofence',
                      arguments: {'deviceId': vehicle.deviceId},
                    ),
              ),
              _buildActionCard(
                icon: Icons.settings,
                title: 'Settings',
                subtitle: 'Vehicle settings',
                color: Colors.grey,
                onTap: () => Navigator.pushNamed(context, '/vehicle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade600, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVehicleSelectionChanged() {
    // This method is called when the vehicle selection changes
    final vehicleProvider = Provider.of<VehicleProvider>(
      context,
      listen: false,
    );

    if (vehicleProvider.hasSelectedVehicle) {
      // Show a brief feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Now tracking: ${vehicleProvider.selectedVehicle!.name}'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Optional: Trigger any data refresh or other actions here
      // For example:
      // - Refresh map data
      // - Update geofence information
      // - Clear cached data for previous vehicle
      _refreshDataForSelectedVehicle();
    }
  }

  void _refreshDataForSelectedVehicle() {
    // Implement any data refresh logic here
    print('Refreshing data for selected vehicle...');

    // Example refresh actions:
    // - Clear cached map data
    // - Refresh geofence data
    // - Update real-time location stream
    // - Refresh driving history
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../services/Auth/AuthService.dart';
import '../../services/maps/mapsService.dart';
import '../../widgets/mapWidget.dart';

class GPSMapScreen extends StatefulWidget {
  const GPSMapScreen({super.key});

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  static const String deviceId = 'B0A7322B2EC4'; // Make this configurable later
  late final mapServices _mapService;

  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String? locationName = 'Loading Location...';
  bool isVehicleOn = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _mapService = mapServices(deviceId: deviceId);
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // Listen to GPS data changes
    _mapService.getGPSDataStream().listen((gpsData) {
      if (mounted && gpsData != null && _mapService.isGPSDataValid(gpsData)) {
        _updateGPSData(gpsData);
      }
    });

    // Listen to relay status changes
    _mapService.getRelayStatusStream().listen((relayStatus) {
      if (mounted) {
        setState(() {
          isVehicleOn = relayStatus;
        });
      }
    });

    // Load initial data
    _loadInitialData();
  }

  Future<void> _updateGPSData(Map<String, dynamic> gpsData) async {
    try {
      final lat = gpsData['latitude'] as double;
      final lon = gpsData['longitude'] as double;

      // Fetch location name (but don't wait for it to update other data)
      _mapService.fetchLocationName(lat, lon).then((locationName) {
        if (mounted) {
          setState(() {
            this.locationName = locationName;
          });
        }
      });

      setState(() {
        latitude = lat;
        longitude = lon;
        lastUpdated =
            gpsData['waktu_wita']?.toString() ??
            gpsData['time']?.toString() ??
            DateTime.now().toString();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error updating GPS data: $e');
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Load initial GPS location
      final gpsData = await _mapService.getLastGPSLocation();
      if (gpsData != null && _mapService.isGPSDataValid(gpsData)) {
        await _updateGPSData(gpsData);
      }

      // Load initial relay status
      final relayStatus = await _mapService.getCurrentRelayStatus();
      if (mounted) {
        setState(() {
          isVehicleOn = relayStatus;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });

    await _loadInitialData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Pass deviceId to MapWidget
          MapWidget(deviceId: deviceId),

          // Top navigation bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/appicon1.svg',
                          height: 25,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.refresh),
                          onPressed: isLoading ? null : _refreshData,
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.person, color: Colors.black),
                          offset: const Offset(0, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          color: Colors.white,
                          shadowColor: Colors.black.withOpacity(0.2),
                          onSelected: (value) async {
                            switch (value) {
                              case 'profile':
                                Navigator.pushNamed(context, '/vehicle');
                                break;
                              case 'settings':
                                Navigator.pushNamed(context, '/settings');
                                break;
                              case 'logout':
                                await AuthService.signOut();
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                                break;
                            }
                          },
                          itemBuilder:
                              (context) => const [
                                PopupMenuItem(
                                  value: 'profile',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_outline),
                                      SizedBox(width: 8),
                                      Text('Profile'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings_outlined),
                                      SizedBox(width: 8),
                                      Text('Settings'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout_outlined),
                                      SizedBox(width: 8),
                                      Text('Logout'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom information panel
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locationName ?? 'Loading...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // GPS Coordinates
                  if (latitude != null && longitude != null)
                    Row(
                      children: [
                        Text(
                          'Lat: ${latitude!.toStringAsFixed(5)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Lng: ${longitude!.toStringAsFixed(5)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'GPS coordinates unavailable',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Last updated info
                  Text(
                    lastUpdated != '-' && lastUpdated.isNotEmpty
                        ? 'Last Active: $lastUpdated'
                        : 'Waiting for GPS data...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          (latitude != null && longitude != null)
                              ? Colors.green[600]
                              : Colors.orange[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Column(
                    children: [
                      // Navigation button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (latitude != null && longitude != null)
                                  ? () {
                                    // TODO: Implement navigation functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Navigation feature coming soon!',
                                        ),
                                      ),
                                    );
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: const Color(
                              0xFF7DAEFF,
                            ).withOpacity(0.25),
                            foregroundColor: const Color(0xFF11468F),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.rotate(
                                angle: 0.45,
                                child: const Icon(Icons.navigation, size: 20),
                              ),
                              const SizedBox(width: 8),
                              const Text('Navigate to Location'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Vehicle control button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await _mapService.toggleRelayStatus();
                              // Status will be updated automatically through the stream listener
                            } catch (e) {
                              debugPrint('Error toggling vehicle status: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to toggle vehicle: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor:
                                isVehicleOn
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVehicleOn
                                    ? Icons.power_settings_new
                                    : Icons.power_settings_new_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVehicleOn
                                    ? 'Turn Off Vehicle'
                                    : 'Turn On Vehicle',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

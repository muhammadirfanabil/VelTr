import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/Auth/AuthService.dart';
import '../../services/maps/mapsService.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/mapWidget.dart';
import '../../widgets/stickyFooter.dart';
import '../../widgets/motoricon.dart';
import '../../widgets/tracker.dart';

class GPSMapScreen extends StatefulWidget {
  final String deviceId;

  const GPSMapScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  late final DeviceService _deviceService;
  mapServices? _mapService;
  String? currentDeviceId;
  String? deviceName;

  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  bool isVehicleOn = false;
  bool isLoading = true;
  final MapController _mapController = MapController();

  LatLng get vehicleLocation =>
      (latitude != null && longitude != null)
          ? LatLng(latitude!, longitude!)
          : LatLng(-6.200000, 106.816666);

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();
    _initializeWithUserDevice();
  }

  /// Initialize the map service with the current user's primary device
  Future<void> _initializeWithUserDevice() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Use the enhanced bridge method to get validated MAC ID
      final macId = await _deviceService.getValidatedDeviceMacIdForMap();

      if (macId == null) {
        throw Exception(
          'No valid devices found or device not connected to GPS system',
        );
      }

      // Get the device name for display using the MAC ID
      final name = await _deviceService.getDeviceNameById(macId);

      // Initialize the map service with the MAC ID for Firebase Realtime Database access
      final mapService = mapServices(deviceId: macId);

      setState(() {
        currentDeviceId = macId;
        deviceName = name ?? macId; // Show MAC ID if no name available
        _mapService = mapService;
      });

      // Set up real-time listeners and load initial data
      _setupRealtimeListeners();
      await _loadInitialData();
    } catch (e) {
      debugPrint('Error initializing with user device: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        // Provide specific error messages for bridge connection issues
        String errorMessage = 'Failed to initialize device: $e';
        if (e.toString().contains('No valid devices found')) {
          errorMessage =
              'No GPS devices found or device not connected to GPS system. Please check your device setup.';
        } else if (e.toString().contains('not connected to GPS system')) {
          errorMessage =
              'Device found but not sending GPS data. Please check your physical GPS device connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _setupRealtimeListeners() {
    if (_mapService == null) return;

    // Listen to GPS data changes
    _mapService!.getGPSDataStream().listen((gpsData) {
      if (mounted && gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        _updateGPSData(gpsData);
      }
    });

    // Listen to relay status changes
    _mapService!.getRelayStatusStream().listen((relayStatus) {
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
      _mapService?.fetchLocationName(lat, lon).then((locationName) {
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

      // Move map to new position if coordinates are valid
      if (lat != null && lon != null) {
        _mapController.move(LatLng(lat, lon), 15.0);
      }
    } catch (e) {
      debugPrint('Error updating GPS data: $e');
    }
  }

  Future<void> _loadInitialData() async {
    if (_mapService == null) return;

    try {
      // Load initial GPS location
      final gpsData = await _mapService!.getLastGPSLocation();
      if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        await _updateGPSData(gpsData);
      }

      // Load initial relay status
      final relayStatus = await _mapService!.getCurrentRelayStatus();
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

  bool get isRecentlyActive {
    if (lastUpdated == '-' || lastUpdated == 'Unavailable') return false;

    try {
      final lastUpdate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(lastUpdated);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);

      // Consider active if updated within last 5 minutes
      return difference.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }

  void toggleVehicleStatus() async {
    if (_mapService == null) return;

    try {
      await _mapService!.toggleRelayStatus();
      // Status will be updated automatically through the stream listener
    } catch (e) {
      debugPrint('Error toggling vehicle status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showVehiclePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleStatusPanel(
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: lastUpdated,
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
          ),
    );
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
          // Use MapWidget with both backend service and direct Firebase support
          MapWidget(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: vehicleLocation,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            deviceId: currentDeviceId,
            children: [
              // OSM Humanitarian tile layer
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gps_app',
                maxZoom: 18,
              ),
              MarkerLayer(
                markers: [
                  // Vehicle marker - always show if we have coordinates
                  Marker(
                    point: vehicleLocation,
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: showVehiclePanel,
                      child: VehicleMarkerIcon(isOn: isVehicleOn),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top floating controls - simplified without app bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Device info
                  if (deviceName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                  // Action buttons
                  Row(
                    children: [
                      // Refresh button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
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
                      ),
                      const SizedBox(width: 8),
                      // User menu
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PopupMenuButton<String>(
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
                                Navigator.pushNamed(context, '/profile');
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Sticky footer
          Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

// VehicleMarkerIcon widget from motoricon.dart is used

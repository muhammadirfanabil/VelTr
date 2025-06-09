import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../services/Auth/AuthService.dart';
import '../../services/maps/mapsService.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/mapWidget.dart';
import '../../widgets/stickyFooter.dart';
import '../../widgets/motoricon.dart';
import '../../widgets/tracker.dart';

class GPSMapScreen extends StatefulWidget {
  final String deviceId;
  final String userId;

  GPSMapScreen({Key? key, required this.deviceId})
    : userId = AuthService.getCurrentUserId() ?? '',
      super(key: key);

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  late final DeviceService _deviceService;
  late final VehicleService _vehicleService;
  mapServices? _mapService;
  String? currentDeviceId;
  String? deviceName;

  // Vehicle selection
  List<vehicle> availableVehicles = [];
  bool isLoadingVehicles = false;

  String lastUpdated = '-';
  int? satellites;
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  String? waktuWita;
  bool isVehicleOn = false;
  bool isLoading = true;
  bool hasGPSData = false;
  bool showNoGPSDialog = false;
  final MapController _mapController = MapController();

  // Default location (you can change this to your preferred default location)
  static const LatLng defaultLocation = LatLng(
    -6.2088,
    106.8456,
  ); // Jakarta, Indonesia

  LatLng? get vehicleLocation =>
      (latitude != null && longitude != null)
          ? LatLng(latitude!, longitude!)
          : null;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();
    _vehicleService = VehicleService();
    currentDeviceId = widget.deviceId;
    _loadAvailableVehicles();
    _initializeWithDevice();
  }

  void _loadAvailableVehicles() {
    setState(() => isLoadingVehicles = true);

    // Use the stream to get real-time updates of vehicles
    _vehicleService.getVehiclesStream().listen(
      (vehicles) {
        if (mounted) {
          setState(() {
            availableVehicles = vehicles;
            isLoadingVehicles = false;
          });
        }
      },
      onError: (e) {
        debugPrint('Error loading vehicles: $e');
        if (mounted) {
          setState(() {
            availableVehicles = [];
            isLoadingVehicles = false;
          });
        }
      },
    );
  }

  Future<void> _switchToVehicle(String vehicleId, String vehicleName) async {
    if (vehicleId == currentDeviceId) return;

    setState(() {
      isLoading = true;
      currentDeviceId = vehicleId;
      deviceName = vehicleName;
      // Reset current data
      latitude = null;
      longitude = null;
      locationName = 'Loading Location...';
      lastUpdated = '-';
      satellites = null;
      waktuWita = null;
      isVehicleOn = false;
      hasGPSData = false;
      showNoGPSDialog = false;
    });

    // Initialize with new vehicle
    await _initializeWithDevice();
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, size: 24),
                      const SizedBox(width: 12),
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

                const Divider(height: 1),

                // Vehicle list
                if (isLoadingVehicles)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (availableVehicles.isEmpty)
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
                      itemCount: availableVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = availableVehicles[index];
                        final isSelected = vehicle.deviceId == currentDeviceId;

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
                              _switchToVehicle(vehicle.deviceId!, vehicle.name);
                            }
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _initializeWithDevice() async {
    try {
      setState(() => isLoading = true);

      final name = await _deviceService.getDeviceNameById(currentDeviceId!);
      final mapService = mapServices(deviceId: currentDeviceId!);

      setState(() {
        deviceName = name ?? currentDeviceId!;
        _mapService = mapService;
      });

      _setupRealtimeListeners();
      await _loadInitialData();
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  void _handleInitializationError(dynamic e) {
    debugPrint('Error initializing device: $e');
    if (mounted) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to initialize device: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _setupRealtimeListeners() {
    _listenToGPSData();
    _listenToRelayStatus();
  }

  void _listenToGPSData() {
    final ref = FirebaseDatabase.instance.ref('devices/$currentDeviceId/gps');

    ref.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          debugPrint('GPS Data received: $data');

          final lat = _parseDouble(data['latitude']);
          final lon = _parseDouble(data['longitude']);
          final tanggal = data['tanggal']?.toString();
          final waktu = data['waktu_wita']?.toString();
          final sat = _parseInt(data['satellites']);

          if (lat != null && lon != null) {
            setState(() {
              latitude = lat;
              longitude = lon;
              waktuWita = waktu;
              satellites = sat;
              isLoading = false;
              hasGPSData = true;
              showNoGPSDialog = false;
            });

            _fetchLocationName(lat, lon);
            _mapController.move(LatLng(lat, lon), 15.0);

            if (tanggal != null && waktu != null) {
              _updateTimestamp('$tanggal $waktu');
            }
          } else {
            setState(() {
              isLoading = false;
              hasGPSData = false;
            });
            if (!showNoGPSDialog) {
              _showNoGPSInfoBanner();
            }
          }
        } else {
          debugPrint('No GPS data found at path: devices/$currentDeviceId/gps');
          setState(() {
            isLoading = false;
            hasGPSData = false;
          });
          if (!showNoGPSDialog) {
            _showNoGPSInfoBanner();
          }
        }
      },
      onError: (error) {
        debugPrint('Firebase GPS listener error: $error');
        setState(() {
          isLoading = false;
          hasGPSData = false;
        });
        if (!showNoGPSDialog) {
          _showNoGPSInfoBanner();
        }
      },
    );
  }

  void _showNoGPSInfoBanner() {
    if (mounted && !showNoGPSDialog) {
      setState(() => showNoGPSDialog = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gps_off, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No GPS data available for ${deviceName ?? currentDeviceId}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: _showNoGPSDetailsDialog,
          ),
        ),
      );
    }
  }

  void _showNoGPSDetailsDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text('GPS Information'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS data is not currently available for this device.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'Device: ${deviceName ?? currentDeviceId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can still:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• View the map interface'),
                const Text('• Access other app features'),
                const Text('• Control device relay status'),
                const Text('• Switch to another vehicle'),
                const Text('• Return later when GPS is available'),
                const SizedBox(height: 16),
                const Text(
                  'To enable GPS tracking:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• Ensure device is powered on'),
                const Text('• Check GPS module functionality'),
                const Text('• Verify network connection'),
                const Text('• Confirm data transmission to server'),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _refreshData();
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    }
  }

  void _listenToRelayStatus() {
    final relayRef = FirebaseDatabase.instance.ref(
      'devices/$currentDeviceId/relay',
    );

    relayRef.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final status = event.snapshot.value as bool? ?? false;
          if (mounted) {
            setState(() => isVehicleOn = status);
          }
        }
      },
      onError: (error) {
        debugPrint('Firebase relay listener error: $error');
      },
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _updateTimestamp(String timestamp) {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
      setState(() {
        lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      });
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      setState(() {
        lastUpdated = 'Invalid timestamp';
      });
    }
  }

  Future<void> _loadInitialData() async {
    final ref = FirebaseDatabase.instance.ref('devices/$currentDeviceId/gps');

    try {
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Initial GPS Data: $data');

        final lat = _parseDouble(data['latitude']);
        final lon = _parseDouble(data['longitude']);

        if (lat != null && lon != null) {
          setState(() {
            latitude = lat;
            longitude = lon;
            waktuWita = data['waktu_wita']?.toString();
            satellites = _parseInt(data['satellites']);
            isLoading = false;
            hasGPSData = true;
          });

          _fetchLocationName(lat, lon);
          _mapController.move(LatLng(lat, lon), 15.0);

          final tanggal = data['tanggal']?.toString();
          final waktu = data['waktu_wita']?.toString();
          if (tanggal != null && waktu != null) {
            _updateTimestamp('$tanggal $waktu');
          }
        } else {
          setState(() {
            isLoading = false;
            hasGPSData = false;
          });
          _showNoGPSInfoBanner();
        }
      } else {
        setState(() {
          isLoading = false;
          hasGPSData = false;
        });
        _showNoGPSInfoBanner();
      }

      // Get initial relay status
      final relaySnapshot =
          await FirebaseDatabase.instance
              .ref('devices/$currentDeviceId/relay')
              .get();
      if (relaySnapshot.exists) {
        setState(() {
          isVehicleOn = relaySnapshot.value as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() {
        isLoading = false;
        hasGPSData = false;
      });
      _showNoGPSInfoBanner();
    }
  }

  Future<void> _fetchLocationName(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterApp'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            locationName = data['display_name'] ?? 'Location Not Found';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching location name: $e");
    }
  }

  void toggleVehicleStatus() {
    final relayRef = FirebaseDatabase.instance.ref(
      'devices/$currentDeviceId/relay',
    );

    final newStatus = !isVehicleOn;
    relayRef.set(newStatus);

    setState(() {
      isVehicleOn = newStatus;
    });
  }

  void showVehiclePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleStatusPanel(
            locationName: hasGPSData ? locationName : 'GPS not available',
            latitude: latitude,
            longitude: longitude,
            waktuWita: waktuWita,
            lastUpdated: hasGPSData ? lastUpdated : 'No GPS data',
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
            satellites: satellites,
          ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      showNoGPSDialog = false;
    });
    await _loadInitialData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasGPSData ? 'GPS data refreshed' : 'Still no GPS data available',
          ),
          backgroundColor: hasGPSData ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDeviceInfoChip() {
    if (deviceName == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showVehicleSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            if (!hasGPSData) ...[
              const Icon(Icons.gps_off, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
            ],
            Text(
              deviceName!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildFloatingButton(
          child:
              isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          onPressed: isLoading ? null : _refreshData,
        ),
        const SizedBox(width: 8),
        if (!hasGPSData)
          _buildFloatingButton(
            child: const Icon(Icons.info_outline),
            onPressed: _showNoGPSDetailsDialog,
          ),
        const SizedBox(width: 8),
        _buildUserMenu(),
      ],
    );
  }

  Widget _buildFloatingButton({
    required Widget child,
    VoidCallback? onPressed,
  }) {
    return Container(
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
      child: IconButton(icon: child, onPressed: onPressed),
    );
  }

  Widget _buildUserMenu() {
    return Container(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        color: Colors.white,
        onSelected: _handleMenuSelection,
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home_outlined),
                    SizedBox(width: 8),
                    Text('Home'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
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
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'home':
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        await AuthService.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  Widget _buildMapWithOverlay() {
    return Stack(
      children: [
        // Always show the map, with GPS location if available, otherwise default location
        MapWidget(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: vehicleLocation ?? defaultLocation,
            initialZoom: hasGPSData ? 15.0 : 10.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          deviceId: currentDeviceId,
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.gps_app',
              maxZoom: 18,
            ),
            if (hasGPSData && vehicleLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: vehicleLocation!,
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
        // Show overlay message when no GPS data
        if (!hasGPSData && !isLoading)
          Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gps_off, size: 48, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text(
                    'GPS Not Available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Device: ${deviceName ?? currentDeviceId}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You can switch to another vehicle or control this device.',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showVehicleSelector,
                        icon: const Icon(Icons.directions_car, size: 18),
                        label: const Text('Switch Vehicle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Show loading indicator while loading
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          // Always show map (with overlay if no GPS data)
          else
            _buildMapWithOverlay(),

          // Always show top controls
          if (!isLoading)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDeviceInfoChip(), _buildActionButtons()],
                ),
              ),
            ),

          // Always show footer
          if (!isLoading)
            Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

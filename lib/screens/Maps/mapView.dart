import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../services/Auth/AuthService.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../models/Geofence/Geofence.dart';
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
  late final GeofenceService _geofenceService;
  String? currentDeviceId;
  String? deviceName;

  // Firebase listeners for proper disposal
  StreamSubscription<DatabaseEvent>? _gpsListener;
  StreamSubscription<DatabaseEvent>? _relayListener;
  StreamSubscription<List<vehicle>>? _vehicleListener;
  StreamSubscription<List<Geofence>>? _geofenceListener;

  // Vehicle selection
  List<vehicle> availableVehicles = [];
  bool isLoadingVehicles = false;

  // Geofence overlay state
  List<Geofence> deviceGeofences = [];
  bool showGeofences = false;
  bool isLoadingGeofences = false;
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
    _geofenceService =
        GeofenceService(); // Initialize with device name resolution
    _initializeDeviceId();
    _loadAvailableVehicles();
  }

  Future<void> _initializeDeviceId() async {
    debugPrint('🔧 [DEVICE_INIT] Starting device initialization...');
    debugPrint('🔧 [DEVICE_INIT] Widget deviceId: ${widget.deviceId}');

    try {
      // If widget.deviceId is passed, it might be a Firestore device ID
      // We need to get the actual device name (MAC address) for Firebase Realtime Database
      final deviceName = await _deviceService.getDeviceNameById(
        widget.deviceId,
      );
      debugPrint('🔧 [DEVICE_INIT] Device name from service: $deviceName');

      setState(() {
        currentDeviceId =
            deviceName ??
            widget.deviceId; // Use device.name or fallback to widget.deviceId
      });
      debugPrint('🔧 [DEVICE_INIT] Current device ID set to: $currentDeviceId');
      debugPrint(
        'Initialized with device: $currentDeviceId (from widget.deviceId: ${widget.deviceId})',
      );
      await _initializeWithDevice();

      // Load geofences for the current device after initialization is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadGeofencesForDevice();
        }
      });
    } catch (e) {
      debugPrint('❌ [DEVICE_INIT] Error initializing device ID: $e');
      // Fallback to using widget.deviceId directly
      setState(() {
        currentDeviceId = widget.deviceId;
      });
      debugPrint(
        '🔧 [DEVICE_INIT] Fallback - using widget.deviceId: $currentDeviceId',
      );
      await _initializeWithDevice();
    }
  }

  @override
  void dispose() {
    // Cancel all listeners to prevent memory leaks
    _gpsListener?.cancel();
    _relayListener?.cancel();
    _vehicleListener?.cancel();
    _geofenceListener?.cancel();
    super.dispose();
  }

  void _loadAvailableVehicles() {
    setState(() => isLoadingVehicles = true);

    // Cancel existing vehicle listener if any
    _vehicleListener?.cancel();

    // Use the stream to get real-time updates of vehicles
    _vehicleListener = _vehicleService.getVehiclesStream().listen(
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

    debugPrint(
      '🔄 Vehicle switch from $currentDeviceId to $vehicleId ($vehicleName)',
    );

    // Cancel existing listeners before switching
    _gpsListener?.cancel();
    _relayListener?.cancel();
    _geofenceListener?.cancel();
    debugPrint('Cancelled listeners for device: $currentDeviceId');

    // Clear geofences completely before switching
    _clearGeofencesCompletely();

    setState(() {
      isLoading = true;
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
      // Reset geofence data (already cleared above, but ensure state is consistent)
      deviceGeofences = [];
      isLoadingGeofences = false;
    });

    // Get the actual device name (MAC address) for Firebase Realtime Database
    try {
      final deviceName = await _deviceService.getDeviceNameById(vehicleId);
      if (deviceName != null) {
        setState(() {
          currentDeviceId =
              deviceName; // Use device.name (MAC address), not vehicle.deviceId
        });
        debugPrint(
          'Switched to device name: $deviceName for vehicle: $vehicleName',
        );
      } else {
        debugPrint('Could not find device name for vehicleId: $vehicleId');
        setState(() {
          currentDeviceId = vehicleId; // Fallback to vehicleId
        });
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
      setState(() {
        currentDeviceId = vehicleId; // Fallback to vehicleId
      });
    } // Initialize with new vehicle
    await _initializeWithDevice();
    // If geofence overlay is enabled, load geofences for the new device
    if (showGeofences) {
      debugPrint('🔄 Reloading geofences for switched vehicle: $vehicleId');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Load geofences using the vehicle ID instead of widget.deviceId
          _loadGeofencesForSpecificDevice(vehicleId);
        }
      });
    }
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.devices, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No vehicles available',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a device to start tracking',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/device');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Device'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: Column(
                      children: [
                        // Vehicle list
                        ...List.generate(availableVehicles.length, (index) {
                          final vehicle = availableVehicles[index];

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
                                    color:
                                        isSelected ? Colors.blue : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  vehicle.name,
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected ? Colors.blue : Colors.black,
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
                                    _switchToVehicle(
                                      vehicle.deviceId!,
                                      vehicle.name,
                                    );
                                  }
                                },
                              );
                            },
                          );
                        }),
                        // Add Device option
                        const Divider(),
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.add, color: Colors.green),
                          ),
                          title: const Text(
                            'Add Device',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                          subtitle: const Text(
                            'Set up a new GPS device',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.green,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/device');
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  /// Helper method to check if a vehicle is currently selected
  Future<bool> _isVehicleSelected(vehicle vehicleToCheck) async {
    if (vehicleToCheck.deviceId == null) return false;

    try {
      // Get the device name (MAC address) for this vehicle
      final deviceName = await _deviceService.getDeviceNameById(
        vehicleToCheck.deviceId!,
      );

      // Compare with the current device ID (which should be the MAC address)
      return deviceName == currentDeviceId;
    } catch (e) {
      debugPrint('Error checking vehicle selection: $e');
      return false;
    }
  }

  Future<void> _initializeWithDevice() async {
    try {
      setState(() => isLoading = true);
      final name = await _deviceService.getDeviceNameById(currentDeviceId!);

      setState(() {
        deviceName = name ?? currentDeviceId!;
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
    // Cancel existing GPS listener if any
    _gpsListener?.cancel();

    final ref = FirebaseDatabase.instance.ref('devices/$currentDeviceId/gps');
    debugPrint(
      '📡 [GPS_LISTENER] Setting up GPS listener for device: $currentDeviceId',
    );
    debugPrint('📡 [GPS_LISTENER] Firebase path: devices/$currentDeviceId/gps');

    // Use managed listener
    _gpsListener = ref.onValue.listen(
      (event) {
        debugPrint('📡 [GPS_LISTENER] GPS data event received');
        debugPrint('📡 [GPS_LISTENER] Event exists: ${event.snapshot.exists}');
        debugPrint('📡 [GPS_LISTENER] Event value: ${event.snapshot.value}');

        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          debugPrint('GPS Data received: $data');

          final lat = _parseDouble(data['latitude']);
          final lon = _parseDouble(data['longitude']);
          final tanggal = data['tanggal']?.toString();
          final waktu = data['waktu_wita']?.toString();
          final sat = _parseInt(data['satellites']);

          debugPrint(
            '📡 [GPS_LISTENER] Parsed - lat: $lat, lon: $lon, satellites: $sat',
          );

          if (lat != null && lon != null) {
            debugPrint(
              '✅ [GPS_LISTENER] Valid GPS coordinates found - setting hasGPSData = true',
            );
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
            _safeMoveMap(LatLng(lat, lon), 15.0);

            if (tanggal != null && waktu != null) {
              _updateTimestamp('$tanggal $waktu');
            }
          } else {
            debugPrint(
              '❌ [GPS_LISTENER] Invalid GPS coordinates - setting hasGPSData = false',
            );
            setState(() {
              isLoading = false;
              hasGPSData = false;
            });
            if (!showNoGPSDialog) {
              _showNoGPSInfoBanner();
            }
          }
        } else {
          debugPrint(
            '❌ [GPS_LISTENER] No GPS data found at path: devices/$currentDeviceId/gps',
          );
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
        debugPrint('❌ [GPS_LISTENER] Firebase GPS listener error: $error');
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
                Text('Device Information'),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Details:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Firestore ID: ${widget.deviceId}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (deviceName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Device Name: $deviceName',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      if (currentDeviceId != null &&
                          currentDeviceId != widget.deviceId) ...[
                        const SizedBox(height: 4),
                        Text(
                          'MAC Address: $currentDeviceId',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
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
    // Cancel existing relay listener if any
    _relayListener?.cancel();

    final relayRef = FirebaseDatabase.instance.ref(
      'devices/$currentDeviceId/relay',
    );
    debugPrint('Setting up relay listener for device: $currentDeviceId');

    // Use managed listener
    _relayListener = relayRef.onValue.listen(
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

  /// Safely moves the map controller, handling timing issues with FlutterMap rendering
  void _safeMoveMap(LatLng position, double zoom) {
    try {
      _mapController.move(position, zoom);
    } catch (e) {
      debugPrint('MapController move error: $e');
      // Retry with progressively longer delays to ensure the map is rendered
      _retryMapMove(position, zoom, 1);
    }
  }

  void _retryMapMove(LatLng position, double zoom, int attempt) {
    final delays = [200, 500, 1000]; // Progressive delays in milliseconds

    if (attempt > delays.length) {
      debugPrint('MapController move failed after ${delays.length} attempts');
      return;
    }

    Future.delayed(Duration(milliseconds: delays[attempt - 1]), () {
      try {
        if (mounted) {
          _mapController.move(position, zoom);
          debugPrint('MapController move succeeded on attempt $attempt');
        }
      } catch (retryError) {
        debugPrint('MapController move attempt $attempt failed: $retryError');
        _retryMapMove(position, zoom, attempt + 1);
      }
    });
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
          _safeMoveMap(LatLng(lat, lon), 15.0);

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

    // Cancel existing listeners and re-establish them for a fresh connection
    _gpsListener?.cancel();
    _relayListener?.cancel();
    debugPrint(
      'Refresh: Cancelled existing listeners for device: $currentDeviceId',
    ); // Reload initial data and restart listeners
    await _loadInitialData();
    _setupRealtimeListeners();

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
    final isNoDevicePlaceholder = currentDeviceId == 'no_device_placeholder';

    if (isNoDevicePlaceholder) {
      // Show special chip for no device scenario
      return GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/device'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300),
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
              Icon(Icons.add, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                'Add Device',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        // Geofence toggle button
        _buildFloatingButton(
          child:
              isLoadingGeofences
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(
                    Icons.layers,
                    color: showGeofences ? Colors.blue : null,
                  ),
          onPressed: isLoadingGeofences ? null : _toggleGeofenceOverlay,
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
    final mapCenter = vehicleLocation ?? defaultLocation;
    final mapZoom = hasGPSData ? 15.0 : 10.0;

    debugPrint('🗺️ [MAP] Building map overlay...');
    debugPrint('🗺️ [MAP] Vehicle location: $vehicleLocation');
    debugPrint('🗺️ [MAP] Default location: $defaultLocation');
    debugPrint('🗺️ [MAP] Final map center: $mapCenter');
    debugPrint('🗺️ [MAP] Final zoom level: $mapZoom');
    debugPrint('🗺️ [MAP] Has GPS data: $hasGPSData');

    return Stack(
      children: [
        // Always show the map, with GPS location if available, otherwise default location
        MapWidget(
          key: ValueKey(
            'map_${widget.deviceId}',
          ), // Force rebuild on device change
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: mapZoom,
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
            // Geofence polygons - render before markers for proper layering
            if (showGeofences && deviceGeofences.isNotEmpty)
              PolygonLayer(
                polygons:
                    deviceGeofences
                        .where((geofence) => geofence.points.length >= 3)
                        .map((geofence) {
                          debugPrint(
                            '🗺️ Rendering geofence: ${geofence.name} with ${geofence.points.length} points',
                          );
                          return Polygon(
                            points:
                                geofence.points
                                    .map(
                                      (point) => LatLng(
                                        point.latitude,
                                        point.longitude,
                                      ),
                                    )
                                    .toList(),
                            color: Colors.blue.withOpacity(0.3),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 3,
                          );
                        })
                        .toList(),
              ),
            // Geofence labels (markers for center points with names)
            if (showGeofences && deviceGeofences.isNotEmpty)
              MarkerLayer(
                markers:
                    deviceGeofences
                        .where((geofence) => geofence.points.length >= 3)
                        .map((geofence) {
                          // Calculate center point of the geofence
                          final centerLat =
                              geofence.points
                                  .map((p) => p.latitude)
                                  .reduce((a, b) => a + b) /
                              geofence.points.length;
                          final centerLng =
                              geofence.points
                                  .map((p) => p.longitude)
                                  .reduce((a, b) => a + b) /
                              geofence.points.length;

                          return Marker(
                            point: LatLng(centerLat, centerLng),
                            width: 120,
                            height: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  geofence.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
              ),
            // Corner point markers for geofences
            if (showGeofences && deviceGeofences.isNotEmpty)
              CircleLayer(
                circles:
                    deviceGeofences
                        .where((geofence) => geofence.points.length >= 3)
                        .expand(
                          (geofence) => geofence.points.map(
                            (point) => CircleMarker(
                              point: LatLng(point.latitude, point.longitude),
                              radius: 4,
                              color: Colors.blue.withOpacity(0.8),
                              borderStrokeWidth: 2,
                              borderColor: Colors.white,
                            ),
                          ),
                        )
                        .toList(),
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
      ],
    );
  } // Geofence functionality

  Widget _buildSubtleNotificationBanner() {
    debugPrint('🔔 [BANNER] Building banner - hasGPSData: $hasGPSData');
    debugPrint('🔔 [BANNER] Current device ID: $currentDeviceId');

    // Check if user has no real devices (using placeholder)
    final isNoDevicePlaceholder = currentDeviceId == 'no_device_placeholder';

    if (isNoDevicePlaceholder) {
      debugPrint(
        '🔔 [BANNER] No device placeholder detected - showing Add Device banner',
      );
      return _buildAddDeviceBanner();
    }

    if (hasGPSData) {
      debugPrint('🔔 [BANNER] Has GPS data - hiding banner');
      return const SizedBox.shrink();
    } // Determine banner message based on current state
    String bannerMessage = 'No GPS data available for this device.';
    debugPrint('🔔 [BANNER] Showing no GPS message');

    debugPrint('🔔 [BANNER] Banner message: "$bannerMessage"');

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                bannerMessage,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDeviceBanner() {
    debugPrint('🔔 [ADD_DEVICE_BANNER] Building Add Device banner');

    return SafeArea(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.device_hub,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No GPS Devices Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a GPS device to start tracking',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  debugPrint('🔔 [ADD_DEVICE_BANNER] Add Device button tapped');
                  Navigator.pushNamed(context, '/device');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.orange.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Add Device',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadGeofencesForDevice() {
    if (widget.deviceId.isEmpty) {
      debugPrint('🚫 Cannot load geofences: No device ID');
      return;
    }

    setState(() {
      isLoadingGeofences = true;
      deviceGeofences = []; // Clear existing geofences immediately
    });

    debugPrint(
      '🔄 Loading geofences for device: ${widget.deviceId} (Firestore document ID)',
    );
    debugPrint('🔄 Current device MAC address: $currentDeviceId');

    // Cancel previous listener and wait a bit to ensure cleanup
    _geofenceListener?.cancel();
    _geofenceListener = null;

    // Clear the geofences list again to ensure it's empty
    deviceGeofences.clear();

    // Small delay to ensure previous listener is fully cancelled
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      debugPrint(
        '🔄 Starting new geofence stream for device: ${widget.deviceId}',
      );

      // Use widget.deviceId (Firestore document ID) instead of currentDeviceId (MAC address)
      _geofenceListener = _geofenceService
          .getGeofencesStream(widget.deviceId)
          .listen(
            (geofences) {
              debugPrint(
                '✅ Received ${geofences.length} geofences for device: ${widget.deviceId}',
              );
              for (int i = 0; i < geofences.length; i++) {
                final geofence = geofences[i];
                debugPrint(
                  '   Geofence $i: ${geofence.name} (ID: ${geofence.id}, Device: ${geofence.deviceId}, Points: ${geofence.points.length})',
                );
              }

              if (mounted) {
                setState(() {
                  deviceGeofences = geofences;
                  isLoadingGeofences = false;
                });

                debugPrint(
                  '🗺️ State updated - showGeofences: $showGeofences, deviceGeofences: ${deviceGeofences.length}',
                );

                if (geofences.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Loaded ${geofences.length} geofence(s)'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ℹ️ No geofences found for this device'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            onError: (error) {
              debugPrint('❌ Error loading geofences: $error');
              if (mounted) {
                setState(() {
                  isLoadingGeofences = false;
                  deviceGeofences = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to load geofences: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
    });
  }

  /// Load geofences for a specific device ID (used for vehicle switching)
  void _loadGeofencesForSpecificDevice(String deviceId) {
    if (deviceId.isEmpty) {
      debugPrint('🚫 Cannot load geofences: No device ID provided');
      return;
    }

    setState(() {
      isLoadingGeofences = true;
      deviceGeofences = []; // Clear existing geofences immediately
    });

    debugPrint(
      '🔄 Loading geofences for specific device: $deviceId (Firestore document ID)',
    );
    debugPrint('🔄 Current device MAC address: $currentDeviceId');

    // Cancel previous listener and wait a bit to ensure cleanup
    _geofenceListener?.cancel();
    _geofenceListener = null;

    // Clear the geofences list again to ensure it's empty
    deviceGeofences.clear();

    // Small delay to ensure previous listener is fully cancelled
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      debugPrint('🔄 Starting new geofence stream for device: $deviceId');

      // Use the provided deviceId for geofence loading
      _geofenceListener = _geofenceService
          .getGeofencesStream(deviceId)
          .listen(
            (geofences) {
              debugPrint(
                '✅ Received ${geofences.length} geofences for device: $deviceId',
              );
              for (int i = 0; i < geofences.length; i++) {
                final geofence = geofences[i];
                debugPrint(
                  '   Geofence $i: ${geofence.name} (ID: ${geofence.id}, Device: ${geofence.deviceId}, Points: ${geofence.points.length})',
                );
              }

              if (mounted) {
                setState(() {
                  deviceGeofences = geofences;
                  isLoadingGeofences = false;
                });

                debugPrint(
                  '🗺️ State updated - showGeofences: $showGeofences, deviceGeofences: ${deviceGeofences.length}',
                );

                if (geofences.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Loaded ${geofences.length} geofence(s) for switched device',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ℹ️ No geofences found for this device'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            onError: (error) {
              debugPrint('❌ Error loading geofences for $deviceId: $error');
              if (mounted) {
                setState(() {
                  isLoadingGeofences = false;
                  deviceGeofences = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to load geofences: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
    });
  }

  void _toggleGeofenceOverlay() {
    debugPrint(
      '🔄 Toggle geofence overlay: $showGeofences -> ${!showGeofences}',
    );
    debugPrint('📊 Current geofences count: ${deviceGeofences.length}');

    setState(() {
      showGeofences = !showGeofences;
    });

    // Always reload geofences when enabling overlay to ensure fresh data
    if (showGeofences) {
      debugPrint('🔄 Loading geofences because overlay enabled');
      _loadGeofencesForDevice();
    }

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          showGeofences
              ? 'Geofence overlay enabled (${deviceGeofences.length} geofences)'
              : 'Geofence overlay disabled',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: showGeofences ? Colors.green : Colors.grey,
      ),
    );
  }

  @override
  void didUpdateWidget(GPSMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if device ID has changed
    if (oldWidget.deviceId != widget.deviceId) {
      debugPrint(
        '🔄 Device switched from ${oldWidget.deviceId} to ${widget.deviceId}',
      );

      // Clear geofences completely before any other operations
      _clearGeofencesCompletely();

      // Force a map rebuild by clearing and rebuilding the entire widget
      debugPrint('🗺️ Forcing map rebuild after device switch');

      // Update current device ID (but prevent automatic geofence loading)
      _initializeDeviceIdForSwitch();

      // If geofence overlay is enabled, load geofences for new device after a short delay
      if (showGeofences) {
        debugPrint('🔄 Loading geofences for new device: ${widget.deviceId}');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadGeofencesForDevice();
          }
        });
      }
    }
  }

  Future<void> _initializeDeviceIdForSwitch() async {
    try {
      // If widget.deviceId is passed, it might be a Firestore device ID
      // We need to get the actual device name (MAC address) for Firebase Realtime Database
      final deviceName = await _deviceService.getDeviceNameById(
        widget.deviceId,
      );

      setState(() {
        currentDeviceId =
            deviceName ??
            widget.deviceId; // Use device.name or fallback to widget.deviceId
      });
      debugPrint(
        'Device switch - Initialized with device: $currentDeviceId (from widget.deviceId: ${widget.deviceId})',
      );

      // Initialize device data but WITHOUT loading geofences
      await _initializeWithDevice();
    } catch (e) {
      debugPrint('Error initializing device ID during switch: $e');
      // Fallback to using widget.deviceId directly
      setState(() {
        currentDeviceId = widget.deviceId;
      });
      await _initializeWithDevice();
    }
  }

  void _clearGeofencesCompletely() {
    debugPrint('🧹 Clearing geofences completely for device switch');

    // Cancel any existing listener
    _geofenceListener?.cancel();
    _geofenceListener = null;

    // Clear the list completely
    deviceGeofences.clear();

    // Force a complete widget rebuild
    setState(() {
      deviceGeofences = [];
      isLoadingGeofences = false;
    });

    debugPrint('🧹 Geofences cleared - count now: ${deviceGeofences.length}');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔧 [BUILD] Building GPSMapScreen...');
    debugPrint('🔧 [BUILD] Current device ID: $currentDeviceId');
    debugPrint('🔧 [BUILD] Has GPS data: $hasGPSData');
    debugPrint('🔧 [BUILD] Is loading: $isLoading');

    final isNoDevicePlaceholder = currentDeviceId == 'no_device_placeholder';
    final showBanner = isNoDevicePlaceholder || !hasGPSData;
    final topPadding =
        showBanner ? 84.0 : 16.0; // Adjust padding based on banner presence

    debugPrint('🔧 [BUILD] Is no device placeholder: $isNoDevicePlaceholder');
    debugPrint('🔧 [BUILD] Show banner: $showBanner');
    debugPrint('🔧 [BUILD] Top padding: $topPadding');
    return Scaffold(
      body: Stack(
        children: [
          // Show loading indicator while loading
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          // Always show map (with overlay if no GPS data)
          else
            _buildMapWithOverlay(),

          // Always show top controls (above banner)
          if (!isLoading)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDeviceInfoChip(), _buildActionButtons()],
                ),
              ),
            ),

          // Notification banner (moved to z-layer 1, behind top controls)
          if (!isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildSubtleNotificationBanner(),
            ),

          // Always show footer
          if (!isLoading)
            Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

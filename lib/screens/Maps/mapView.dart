import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// Services and models
import '../../services/Auth/AuthService.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';
import '../../services/Geofence/geofenceService.dart';
// import '../../services/notifications/enhanced_notification_service.dart';
import '../../services/maps/mapsService.dart';
import '../../models/Geofence/Geofence.dart';

// Widgets and utilities
import '../../widgets/Map/mapWidget.dart';
import '../../widgets/Common/stickyFooter.dart';
import '../../widgets/motoricon.dart';
import '../../widgets/tracker.dart';
import '../../widgets/Map/vehicle_selector.dart';
import '../../widgets/Map/nogps_overlay.dart';
import '../../widgets/Map/deviceinfo_chip.dart';
import '../../widgets/Map/action_buttons.dart';
import '../../widgets/Map/roundvehicle_marker.dart';
import '../../widgets/Map/subtlenotif_banner.dart';
import '../../widgets/Map/centering_buttons.dart';
import '../../utils/snackbar.dart';

import '../../theme/app_colors.dart';

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
  String? currentVehicleId; // Track current vehicle ID for geofences
  String? deviceName;

  // Firebase listeners for proper disposal
  StreamSubscription<DatabaseEvent>? _gpsListener;
  StreamSubscription<DatabaseEvent>? _relayListener;
  StreamSubscription<List<vehicle>>? _vehicleListener;
  StreamSubscription<List<Geofence>>? _geofenceListener;

  // Vehicle selection
  List<vehicle> availableVehicles = [];
  bool isLoadingVehicles = false;

  // Geofence overlay state - simplified approach matching add/update flow
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
  // User location state
  StreamSubscription<LatLng?>? _userLocationSubscription;
  LatLng? _userLocation;
  bool _isLoadingUserLocation = false;

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
    _initializeUserLocation();
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
        currentVehicleId =
            widget.deviceId; // Initialize with widget device ID for geofences
      });
      debugPrint('🔧 [DEVICE_INIT] Current device ID set to: $currentDeviceId');
      debugPrint(
        'Initialized with device: $currentDeviceId (from widget.deviceId: ${widget.deviceId})',
      );
      await _initializeWithDevice();

      // Initialize geofence overlay with simple loading (like add/update flow)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadGeofenceOverlayDataForVehicle(
            currentVehicleId ?? widget.deviceId,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ [DEVICE_INIT] Error initializing device ID: $e');
      // Fallback to using widget.deviceId directly
      setState(() {
        currentDeviceId = widget.deviceId;
        currentVehicleId = widget.deviceId; // Also set fallback for vehicle ID
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
    _userLocationSubscription?.cancel();

    super.dispose();
  }

  /// Initialize user location tracking
  Future<void> _initializeUserLocation() async {
    debugPrint('🗺️ [MAPVIEW] Initializing user location tracking...');

    setState(() {
      _isLoadingUserLocation = true;
    });

    try {
      // Check if location service is available first
      bool isAvailable = await mapServices.isLocationServiceAvailable();
      debugPrint('🗺️ [MAPVIEW] Location service available: $isAvailable');

      if (!isAvailable) {
        debugPrint(
          '🗺️ [MAPVIEW] Location service not available - cannot initialize user location',
        );
        setState(() {
          _isLoadingUserLocation = false;
        });
        return;
      }

      // Get initial location
      final initialLocation = await mapServices.getCurrentUserLocation();
      debugPrint('🗺️ [MAPVIEW] Initial user location: $initialLocation');

      if (mounted && initialLocation != null) {
        setState(() {
          _userLocation = initialLocation;
          _isLoadingUserLocation = false;
        });
        debugPrint('🗺️ [MAPVIEW] User location state updated successfully');
      }

      // Start location tracking stream
      debugPrint('🗺️ [MAPVIEW] Starting location stream...');
      _userLocationSubscription = mapServices.getUserLocationStream().listen(
        (location) {
          debugPrint('🗺️ [MAPVIEW] Received location update: $location');
          if (mounted && location != null) {
            setState(() {
              _userLocation = location;
            });
            debugPrint(
              '🗺️ [MAPVIEW] User location updated in UI: ${location.latitude}, ${location.longitude}',
            );
          }
        },
        onError: (error) {
          debugPrint('🗺️ [MAPVIEW] Location stream error: $error');
          if (mounted) {
            setState(() {
              _isLoadingUserLocation = false;
            });
          }
        },
        onDone: () {
          debugPrint('🗺️ [MAPVIEW] Location stream ended');
          if (mounted) {
            setState(() {
              _isLoadingUserLocation = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('🗺️ [MAPVIEW] Failed to initialize user location: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserLocation = false;
        });
      }
    }
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
      currentVehicleId = vehicleId; // Update current vehicle ID for geofences
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
    }

    // Initialize with new vehicle
    await _initializeWithDevice();

    // Load geofences for the NEW vehicle ID (not the old widget.deviceId)
    await _handleDeviceSwitchToVehicle(vehicleId);
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleSelectorBottomSheet(
            availableVehicles: availableVehicles,
            isLoadingVehicles: isLoadingVehicles,
            isVehicleSelected: _isVehicleSelected,
            onSwitchToVehicle: (deviceId, vehicleName) {
              _switchToVehicle(deviceId, vehicleName);
            },
            onAttachToDevice: (vehicleId) async {
              // Same device attach logic as before (unchanged)
              final deviceStream = _deviceService.getDevicesStream();
              final devices = await deviceStream.first;
              if (devices.isEmpty) {
                _showNoDevicesDialog();
              } else {
                Navigator.pushNamed(
                  context,
                  '/vehicle/edit',
                  arguments: vehicleId,
                );
              }
            },
            onAddDevice: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/device');
            },
            deviceService: _deviceService,
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
      SnackbarUtils.showError(context, 'Failed to initialize device: $e');
    }
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

      SnackbarUtils.showNoGPSInfo(
        context,
        deviceName ?? currentDeviceId!,
        _showNoGPSDetailsDialog,
      );
    }
  }

  void _showNoGPSDetailsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => NoGPSDetailsDialog(
            firestoreId: widget.deviceId,
            deviceName: deviceName,
            currentDeviceId: currentDeviceId,
            onRetry: _refreshData,
          ),
    );
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
    // Check if the timestamp is valid before parsing
    if (timestamp.isEmpty ||
        timestamp == '-' ||
        timestamp == 'Invalid timestamp') {
      setState(() {
        lastUpdated = 'Invalid timestamp'; // Display a friendly error message
      });
      return; // Exit early if timestamp is invalid
    }

    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
      setState(() {
        lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      });
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      setState(() {
        lastUpdated = 'Invalid timestamp'; // Show fallback message on error
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
      isDismissible: true,
      enableDrag: true,
      barrierColor: AppColors.surface.withValues(
        alpha: 0.5,
      ), // semi-transparent overlay
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: VehicleStatusPanel(
              // Use a stable key that doesn't change on every rebuild
              key: ValueKey('vehicle_panel_$currentDeviceId'),
              deviceId: currentDeviceId ?? '', // Add deviceId parameter
              locationName: hasGPSData ? locationName : 'GPS not available',
              latitude: latitude,
              longitude: longitude,
              waktuWita: waktuWita,
              lastUpdated: hasGPSData ? lastUpdated : 'No GPS data',
              isVehicleOn: isVehicleOn,
              toggleVehicleStatus: toggleVehicleStatus,
              onActionCompleted: () => Navigator.of(context).pop(),
              satellites: satellites,
            ),
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
      SnackbarUtils.showInfo(
        context,
        hasGPSData ? 'GPS data refreshed' : 'Still no GPS data available',
      );
    }
  }

  // Widget _buildUserMenu() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white.withValues(alpha: 0.9),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.1),
  //           blurRadius: 8,
  //           offset: const Offset(0, 2),
  //         ),
  //       ],
  //     ),
  //     child: PopupMenuButton<String>(
  //       icon: const Icon(Icons.person, color: Colors.black),
  //       offset: const Offset(0, 45),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       elevation: 8,
  //       color: Colors.white,
  //       onSelected: _handleMenuSelection,
  //       itemBuilder:
  //           (context) => [
  //             const PopupMenuItem(
  //               value: 'home',
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.home_outlined),
  //                   SizedBox(width: 8),
  //                   Text('Home'),
  //                 ],
  //               ),
  //             ),
  //             const PopupMenuItem(
  //               value: 'profile',
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.person_outline),
  //                   SizedBox(width: 8),
  //                   Text('Profile'),
  //                 ],
  //               ),
  //             ),
  //             PopupMenuItem(
  //               value: 'notifications',
  //               child: Row(
  //                 children: [
  //                   Stack(
  //                     clipBehavior: Clip.none,
  //                     children: [
  //                       const Icon(Icons.notifications_outlined),
  //                       StreamBuilder<int>(
  //                         stream:
  //                             EnhancedNotificationService()
  //                                 .getUnreadNotificationCount(),
  //                         builder: (context, snapshot) {
  //                           final unreadCount = snapshot.data ?? 0;
  //                           if (unreadCount == 0)
  //                             return const SizedBox.shrink();

  //                           return Positioned(
  //                             right: -4,
  //                             top: -4,
  //                             child: Container(
  //                               padding: const EdgeInsets.all(2),
  //                               decoration: const BoxDecoration(
  //                                 color: Colors.red,
  //                                 shape: BoxShape.circle,
  //                               ),
  //                               constraints: const BoxConstraints(
  //                                 minWidth: 16,
  //                                 minHeight: 16,
  //                               ),
  //                               child: Text(
  //                                 unreadCount > 9
  //                                     ? '9+'
  //                                     : unreadCount.toString(),
  //                                 style: const TextStyle(
  //                                   color: Colors.white,
  //                                   fontSize: 10,
  //                                   fontWeight: FontWeight.bold,
  //                                 ),
  //                                 textAlign: TextAlign.center,
  //                               ),
  //                             ),
  //                           );
  //                         },
  //                       ),
  //                     ],
  //                   ),
  //                   const SizedBox(width: 8),
  //                   const Text('Notifications'),
  //                 ],
  //               ),
  //             ),
  //             const PopupMenuItem(
  //               value: 'settings',
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.settings_outlined),
  //                   SizedBox(width: 8),
  //                   Text('Settings'),
  //                 ],
  //               ),
  //             ),
  //             const PopupMenuItem(
  //               value: 'logout',
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.logout_outlined),
  //                   SizedBox(width: 8),
  //                   Text('Logout'),
  //                 ],
  //               ),
  //             ),
  //           ],
  //     ),
  //   );
  // }

  // Future<void> _handleMenuSelection(String value) async {
  //   switch (value) {
  //     case 'home':
  //       Navigator.pushReplacementNamed(context, '/home');
  //       break;
  //     case 'profile':
  //       Navigator.pushNamed(context, '/profile');
  //       break;
  //     case 'notifications':
  //       Navigator.pushNamed(context, '/geofence-alerts');
  //       break;
  //     case 'settings':
  //       Navigator.pushNamed(context, '/settings');
  //       break;
  //     case 'logout':
  //       await AuthService.signOut();
  //       Navigator.pushReplacementNamed(context, '/login');
  //       break;
  //   }
  // }

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
            'map_${currentDeviceId}_${deviceGeofences.length}_${showGeofences ? 'overlay' : 'no-overlay'}',
          ), // Force rebuild on device change, geofence count change, or overlay state change
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: mapZoom,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          deviceId:
              currentDeviceId == 'no_device_placeholder'
                  ? null
                  : currentDeviceId,
          initialCenter: mapCenter,
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.gps_app',
              maxZoom: 18,
            ),
            // Debug map rendering state
            Builder(
              builder: (context) {
                debugPrint(
                  '🗺️ [MAP_RENDER] Building map layers - showGeofences: $showGeofences, geofence count: ${deviceGeofences.length}',
                );
                return const SizedBox.shrink();
              },
            ),
            // Geofence polygons - render before markers for proper layering
            if (showGeofences && deviceGeofences.isNotEmpty) ...[
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
                            color: Colors.blue.withValues(alpha: 0.3),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 3,
                          );
                        })
                        .toList(),
              ),
            ] else
              // Debug log when geofences are not being rendered
              Builder(
                builder: (context) {
                  if (showGeofences && deviceGeofences.isEmpty) {
                    debugPrint(
                      '🗺️ [GEOFENCE_RENDER] Overlay enabled but no geofences to render (count: 0) - SHOULD CLEAR PREVIOUS OVERLAYS',
                    );
                  } else if (!showGeofences && deviceGeofences.isNotEmpty) {
                    debugPrint(
                      '🗺️ [GEOFENCE_RENDER] Geofences available (${deviceGeofences.length}) but overlay disabled',
                    );
                  } else if (!showGeofences && deviceGeofences.isEmpty) {
                    debugPrint(
                      '🗺️ [GEOFENCE_RENDER] Overlay disabled and no geofences available',
                    );
                  }
                  return const SizedBox.shrink();
                },
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
                                color: Colors.blue.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
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
                              color: Colors.blue.withValues(alpha: 0.8),
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
              ), // User location marker
            if (_userLocation != null)
              MarkerLayer(
                markers: [mapServices.getUserLocationMarker(_userLocation)!],
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
              color: Colors.black.withValues(alpha: 0.1),
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
              color: Colors.orange.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.black.withValues(alpha: 0.1),
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

  // ======================== SIMPLIFIED GEOFENCE OVERLAY (MATCHING ADD/UPDATE FLOW) ========================

  /// Load geofence overlay data using the same pattern as add/update geofence screens
  Future<void> _loadGeofenceOverlayData() async {
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Loading geofence data for device: ${widget.deviceId}',
    );
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Current device ID (for GPS): $currentDeviceId',
    );
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Widget device ID (for geofences): ${widget.deviceId}',
    );

    if (widget.deviceId.isEmpty) {
      debugPrint('❌ [MAP_OVERLAY_SIMPLE] Cannot load: No device ID');
      return;
    }

    try {
      setState(() {
        isLoadingGeofences = true;
      });

      // Try both the new service method and fall back to the working stream method
      debugPrint('🔄 [MAP_OVERLAY_SIMPLE] Trying new service method first...');
      List<Geofence> geofences = await _geofenceService.loadGeofenceOverlayData(
        widget.deviceId,
      );

      if (geofences.isEmpty) {
        debugPrint(
          '⚠️ [MAP_OVERLAY_SIMPLE] New method returned 0 geofences, trying original stream method...',
        );

        // Fall back to the original working method
        final completer = Completer<List<Geofence>>();
        late StreamSubscription<List<Geofence>> subscription;

        subscription = _geofenceService
            .getGeofencesStream(widget.deviceId)
            .listen(
              (streamGeofences) {
                debugPrint(
                  '📦 [MAP_OVERLAY_SIMPLE] Stream method returned ${streamGeofences.length} geofences',
                );
                subscription.cancel();
                completer.complete(streamGeofences);
              },
              onError: (error) {
                debugPrint(
                  '❌ [MAP_OVERLAY_SIMPLE] Stream method error: $error',
                );
                subscription.cancel();
                completer.complete([]);
              },
            );

        // Wait for the stream to return data
        geofences = await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('⏰ [MAP_OVERLAY_SIMPLE] Stream method timed out');
            subscription.cancel();
            return <Geofence>[];
          },
        );
      }

      if (mounted) {
        setState(() {
          deviceGeofences = geofences;
          isLoadingGeofences = false;
        });
        debugPrint(
          '✅ [MAP_OVERLAY_SIMPLE] Final result: ${geofences.length} geofences loaded',
        );

        // Log first few geofences for debugging
        for (int i = 0; i < geofences.length && i < 3; i++) {
          final geo = geofences[i];
          debugPrint(
            '   Geofence $i: ${geo.name} (${geo.points.length} points, Device: ${geo.deviceId})',
          );
        }

        // Special handling for empty geofence lists to ensure proper clearing
        if (geofences.isEmpty) {
          debugPrint(
            '🧹 [MAP_OVERLAY_SIMPLE] No geofences found for device ${widget.deviceId} - ensuring overlay is properly cleared',
          );
          setState(() {
            deviceGeofences = [];
            showGeofences =
                false; // Disable overlay when no geofences are available
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [MAP_OVERLAY_SIMPLE] Error loading geofences: $e');
      if (mounted) {
        setState(() {
          deviceGeofences = [];
          isLoadingGeofences = false;
        });
      }
    }
  }

  /// Toggle geofence overlay visibility (simple approach)
  Future<void> _toggleGeofenceOverlay() async {
    debugPrint(
      '� [MAP_OVERLAY_SIMPLE] Toggling overlay: $showGeofences -> ${!showGeofences}',
    );

    final newState = !showGeofences;

    setState(() {
      showGeofences = newState;
      isLoadingGeofences =
          newState &&
          deviceGeofences.isEmpty; // Show loading if enabling and no data
    });

    // If enabling overlay and no data loaded, fetch it now
    if (newState && deviceGeofences.isEmpty) {
      debugPrint(
        '🔄 [MAP_OVERLAY_SIMPLE] Loading geofences because overlay enabled and no data',
      );
      // Use current vehicle ID instead of widget.deviceId
      await _loadGeofenceOverlayDataForVehicle(
        currentVehicleId ?? widget.deviceId,
      );

      if (mounted) {
        setState(() {
          isLoadingGeofences = false;
        });
      }
    }

    // Show feedback to user
    if (mounted) {
      SnackbarUtils.showInfo(
        context,
        newState
            ? 'Geofence overlay enabled (${deviceGeofences.length} geofences)'
            : 'Geofence overlay disabled',
      );
    }

    debugPrint('✅ [MAP_OVERLAY_SIMPLE] Toggle complete - new state: $newState');
  }

  /// Handle device switching with simple data reload
  Future<void> _handleDeviceSwitch() async {
    debugPrint(
      '🔄 [MAP_OVERLAY_SIMPLE] Handling device switch to: ${widget.deviceId}',
    );

    // Clear existing data
    setState(() {
      deviceGeofences = [];
      showGeofences = false; // Reset overlay to disabled by default
    });

    // Load new data (always preload like in add/update screens)
    await _loadGeofenceOverlayData();

    debugPrint('✅ [MAP_OVERLAY_SIMPLE] Device switch complete');
  }

  /// Handle device switching to a specific vehicle with proper geofence loading
  Future<void> _handleDeviceSwitchToVehicle(String newVehicleId) async {
    debugPrint(
      '🔄 [MAP_OVERLAY_SIMPLE] Handling device switch to vehicle: $newVehicleId',
    );

    // Clear existing data (already done in _switchToVehicle, but ensure state is clean)
    setState(() {
      deviceGeofences = [];
      showGeofences = false; // Reset overlay to disabled by default
    });

    // Load geofences for the NEW vehicle ID (not the old widget.deviceId)
    await _loadGeofenceOverlayDataForVehicle(newVehicleId);

    debugPrint('✅ [MAP_OVERLAY_SIMPLE] Vehicle device switch complete');
  }

  /// Load geofence overlay data for a specific vehicle ID
  Future<void> _loadGeofenceOverlayDataForVehicle(String vehicleId) async {
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Loading geofence data for vehicle: $vehicleId',
    );
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Current device ID (for GPS): $currentDeviceId',
    );
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Vehicle ID (for geofences): $vehicleId',
    );
    debugPrint(
      '📥 [MAP_OVERLAY_SIMPLE] Current tracked vehicle ID: $currentVehicleId',
    );

    if (isLoadingGeofences) {
      debugPrint(
        '⚠️ [MAP_OVERLAY_SIMPLE] Already loading geofences, skipping...',
      );
      return;
    }

    try {
      setState(() {
        isLoadingGeofences = true;
      });

      // Try both the new service method and fall back to the working stream method
      debugPrint('🔄 [MAP_OVERLAY_SIMPLE] Trying new service method first...');
      List<Geofence> geofences = await _geofenceService.loadGeofenceOverlayData(
        vehicleId,
      );

      if (geofences.isEmpty) {
        debugPrint(
          '⚠️ [MAP_OVERLAY_SIMPLE] New method returned 0 geofences, trying original stream method...',
        );

        // Fall back to the original working method
        final completer = Completer<List<Geofence>>();
        late StreamSubscription<List<Geofence>> subscription;

        subscription = _geofenceService
            .getGeofencesStream(vehicleId)
            .listen(
              (streamGeofences) {
                debugPrint(
                  '📦 [MAP_OVERLAY_SIMPLE] Stream method returned ${streamGeofences.length} geofences',
                );
                subscription.cancel();
                completer.complete(streamGeofences);
              },
              onError: (error) {
                debugPrint(
                  '❌ [MAP_OVERLAY_SIMPLE] Stream method error: $error',
                );
                subscription.cancel();
                completer.complete([]);
              },
            );

        geofences = await completer.future;
      }

      debugPrint(
        '📊 [MAP_OVERLAY_SIMPLE] Successfully loaded ${geofences.length} geofences for vehicle $vehicleId',
      );

      setState(() {
        deviceGeofences = geofences;
        isLoadingGeofences = false;
      });

      // Special handling for empty geofence lists to ensure proper clearing
      if (geofences.isEmpty) {
        debugPrint(
          '🧹 [MAP_OVERLAY_SIMPLE] No geofences found for vehicle $vehicleId - ensuring overlay is properly cleared',
        );
        setState(() {
          deviceGeofences = [];
          showGeofences =
              false; // Disable overlay when no geofences are available
        });
      }
    } catch (error) {
      debugPrint('❌ [MAP_OVERLAY_SIMPLE] Error loading geofences: $error');
      setState(() {
        deviceGeofences = [];
        isLoadingGeofences = false;
      });
    }
  }

  @override
  void didUpdateWidget(GPSMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if device ID has changed
    if (oldWidget.deviceId != widget.deviceId) {
      debugPrint(
        '🔄 Device switched from ${oldWidget.deviceId} to ${widget.deviceId}',
      );

      // Use simplified device switching
      _handleDeviceSwitch();

      // Update current device ID for other map functions
      _initializeDeviceIdForSwitch();
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
    debugPrint(
      '🧹 [MAP_OVERLAY] Clearing geofences completely for device switch',
    );

    // Cancel any existing listener
    _geofenceListener?.cancel();
    _geofenceListener = null;

    // Clear the list completely
    deviceGeofences.clear();

    // Force a complete widget rebuild to clear map overlays
    setState(() {
      deviceGeofences = [];
      showGeofences = false; // Also hide the overlay
    });

    debugPrint(
      '🧹 [MAP_OVERLAY] Geofences cleared - count now: ${deviceGeofences.length}, overlay hidden: ${!showGeofences}',
    );
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          if (isLoading)
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else
            _buildMapWithOverlay(),

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
                  children: [
                    DeviceInfoChip(
                      isNoDevicePlaceholder: isNoDevicePlaceholder,
                      deviceName: deviceName,
                      hasGPSData: hasGPSData,
                      onTap: _showVehicleSelector,
                    ),
                    MapActionButtons(
                      isLoading: isLoading,
                      onRefresh: isLoading ? null : _refreshData,
                      isLoadingGeofences: isLoadingGeofences,
                      onToggleGeofenceOverlay:
                          isLoadingGeofences ? null : _toggleGeofenceOverlay,
                      showGeofences: showGeofences,
                      hasGPSData: hasGPSData,
                      onShowNoGPSDetails: _showNoGPSDetailsDialog,
                      // userMenu: _buildUserMenu(),
                    ),
                  ],
                ),
              ),
            ),

          if (!isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SubtleNotificationBanner(
                currentDeviceId: currentDeviceId,
                hasGPSData: hasGPSData,
                isNoDevicePlaceholder: isNoDevicePlaceholder,
              ),
            ),

          if (!isLoading)
            Align(alignment: Alignment.bottomCenter, child: StickyFooter()),

          if (!isLoading)
            Positioned(
              bottom: 130,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CenteringButtons(
                  isLoadingUserLocation: _isLoadingUserLocation,
                  onCenterOnUser: _centerOnUser,
                  userLocationAvailable: _userLocation != null,
                  onCenterOnDevice: _centerOnDevice,
                  deviceLocationAvailable: vehicleLocation != null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNoDevicesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No Devices Available'),
            content: const Text(
              'You need to add a device before you can attach it to this vehicle. '
              'Would you like to add a device now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/device');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Device'),
              ),
            ],
          ),
    );
  }

  /// Center map on user location with smooth animation
  Future<void> _centerOnUser() async {
    debugPrint('🗺️ [MAPVIEW] Center on user button pressed');

    setState(() {
      _isLoadingUserLocation = true;
    });

    try {
      // Try to get fresh user location
      final userLocation = await mapServices.getCurrentUserLocation();

      if (userLocation != null) {
        // Center map with smooth animation
        _mapController.move(userLocation, 16.0);
        debugPrint(
          '🗺️ [MAPVIEW] ✅ Centered map on user location: ${userLocation.latitude}, ${userLocation.longitude}',
        );

        // Update state with fresh location
        if (mounted) {
          setState(() {
            _userLocation = userLocation;
            _isLoadingUserLocation = false;
          });

          SnackbarUtils.showSuccess(context, 'Centered on your location');
        }
      } else {
        debugPrint(
          '🗺️ [MAPVIEW] ❌ Cannot center on user - location not available',
        );

        if (mounted) {
          setState(() {
            _isLoadingUserLocation = false;
          });

          SnackbarUtils.showWarning(context, 'Your location is not available');
        }
      }
    } catch (e) {
      debugPrint('🗺️ [MAPVIEW] ❌ Error centering on user: $e');

      if (mounted) {
        setState(() {
          _isLoadingUserLocation = false;
        });

        SnackbarUtils.showError(context, 'Failed to get your location');
      }
    }
  }

  /// Center map on device location with smooth animation
  Future<void> _centerOnDevice() async {
    debugPrint('🗺️ [MAPVIEW] Center on device button pressed');

    if (vehicleLocation != null) {
      // Center map with smooth animation
      _mapController.move(vehicleLocation!, 16.0);
      debugPrint(
        '🗺️ [MAPVIEW] ✅ Centered map on device location: ${vehicleLocation!.latitude}, ${vehicleLocation!.longitude}',
      );

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Centered on device location');
      }
    } else {
      debugPrint(
        '🗺️ [MAPVIEW] ❌ Cannot center on device - location not available',
      );

      if (mounted) {
        SnackbarUtils.showWarning(context, 'Device location not available');
      }
    }
  }
}

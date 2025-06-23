import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

import '../device/deviceService.dart';
import '../vehicle/vehicleService.dart';
import '../Geofence/geofenceService.dart';
import '../../models/vehicle/vehicle.dart';
import '../../models/Geofence/Geofence.dart';

/// Service to handle all business logic for map screen functionality
class MapScreenService {
  final DeviceService _deviceService;
  final VehicleService _vehicleService;
  final GeofenceService _geofenceService;
  final FirebaseDatabase _realtimeDB;

  // Stream subscriptions for proper disposal
  StreamSubscription<DatabaseEvent>? _gpsListener;
  StreamSubscription<DatabaseEvent>? _relayListener;
  StreamSubscription<List<vehicle>>? _vehicleListener;
  StreamSubscription<List<Geofence>>? _geofenceListener;

  MapScreenService({
    DeviceService? deviceService,
    VehicleService? vehicleService,
    GeofenceService? geofenceService,
    FirebaseDatabase? realtimeDB,
  }) : _deviceService = deviceService ?? DeviceService(),
       _vehicleService = vehicleService ?? VehicleService(),
       _geofenceService = geofenceService ?? GeofenceService(),
       _realtimeDB = realtimeDB ?? FirebaseDatabase.instance;

  /// Stream controller for GPS data updates
  final StreamController<Map<String, dynamic>> _gpsDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream controller for vehicle state updates
  final StreamController<bool> _vehicleStateController =
      StreamController<bool>.broadcast();

  /// Stream controller for available vehicles
  final StreamController<List<vehicle>> _vehiclesController =
      StreamController<List<vehicle>>.broadcast();

  /// Stream controller for geofence data
  final StreamController<List<Geofence>> _geofencesController =
      StreamController<List<Geofence>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get gpsDataStream => _gpsDataController.stream;
  Stream<bool> get vehicleStateStream => _vehicleStateController.stream;
  Stream<List<vehicle>> get vehiclesStream => _vehiclesController.stream;
  Stream<List<Geofence>> get geofencesStream => _geofencesController.stream;

  /// Initialize device and start listening to data
  Future<String?> initializeDevice(String deviceId) async {
    debugPrint('🔧 [MAP_SERVICE] Starting device initialization...');
    debugPrint('🔧 [MAP_SERVICE] Device ID: $deviceId');

    try {
      // Get the actual device name (MAC address) for Firebase Realtime Database
      final deviceName = await _deviceService.getDeviceNameById(deviceId);
      debugPrint('🔧 [MAP_SERVICE] Device name from service: $deviceName');

      final actualDeviceId = deviceName ?? deviceId;
      debugPrint('🔧 [MAP_SERVICE] Using device ID: $actualDeviceId');

      return actualDeviceId;
    } catch (e) {
      debugPrint('❌ [MAP_SERVICE] Error initializing device ID: $e');
      return deviceId; // Fallback to original deviceId
    }
  }

  /// Start listening to GPS and relay data for a device
  void startDeviceDataListening(String deviceId) {
    debugPrint(
      '🔧 [MAP_SERVICE] Starting data listeners for device: $deviceId',
    );

    _startGPSListener(deviceId);
    _startRelayListener(deviceId);
  }

  /// Start GPS data listener
  void _startGPSListener(String deviceId) {
    _gpsListener?.cancel();

    final gpsRef = _realtimeDB.ref('devices/$deviceId/gps');
    debugPrint('🔧 [MAP_SERVICE] Starting GPS listener for: $deviceId');

    _gpsListener = gpsRef.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final data = Map<String, dynamic>.from(
            event.snapshot.value as Map? ?? {},
          );
          debugPrint('📍 [MAP_SERVICE] GPS data received: $data');
          _gpsDataController.add(data);
        } else {
          debugPrint('📍 [MAP_SERVICE] No GPS data found');
          _gpsDataController.add({});
        }
      },
      onError: (error) {
        debugPrint('❌ [MAP_SERVICE] GPS listener error: $error');
        _gpsDataController.add({});
      },
    );
  }

  /// Start relay data listener
  void _startRelayListener(String deviceId) {
    _relayListener?.cancel();

    final relayRef = _realtimeDB.ref('devices/$deviceId/relay');
    debugPrint('🔧 [MAP_SERVICE] Starting relay listener for: $deviceId');

    _relayListener = relayRef.onValue.listen(
      (event) {
        if (event.snapshot.exists) {
          final relayData = event.snapshot.value;
          bool isVehicleOn = false;

          if (relayData is Map) {
            isVehicleOn =
                relayData['status'] == 'ON' || relayData['status'] == true;
          } else if (relayData is bool) {
            isVehicleOn = relayData;
          } else if (relayData is String) {
            isVehicleOn = relayData.toLowerCase() == 'on' || relayData == '1';
          } else if (relayData is int) {
            isVehicleOn = relayData == 1;
          }

          debugPrint('🔌 [MAP_SERVICE] Vehicle state: $isVehicleOn');
          _vehicleStateController.add(isVehicleOn);
        } else {
          debugPrint('🔌 [MAP_SERVICE] No relay data found');
          _vehicleStateController.add(false);
        }
      },
      onError: (error) {
        debugPrint('❌ [MAP_SERVICE] Relay listener error: $error');
        _vehicleStateController.add(false);
      },
    );
  }

  /// Load available vehicles
  void loadAvailableVehicles() {
    _vehicleListener?.cancel();

    _vehicleListener = _vehicleService.getVehiclesStream().listen(
      (vehicles) {
        debugPrint('🚗 [MAP_SERVICE] Vehicles loaded: ${vehicles.length}');
        _vehiclesController.add(vehicles);
      },
      onError: (e) {
        debugPrint('❌ [MAP_SERVICE] Error loading vehicles: $e');
        _vehiclesController.add([]);
      },
    );
  }

  /// Load geofences for a vehicle
  void loadGeofenceOverlayData(String vehicleId) {
    _geofenceListener?.cancel();

    debugPrint('🗺️ [MAP_SERVICE] Loading geofences for vehicle: $vehicleId');

    _geofenceListener = _geofenceService
        .getGeofencesStream(vehicleId)
        .listen(
          (geofences) {
            debugPrint(
              '🗺️ [MAP_SERVICE] Geofences loaded: ${geofences.length}',
            );
            _geofencesController.add(geofences);
          },
          onError: (e) {
            debugPrint('❌ [MAP_SERVICE] Error loading geofences: $e');
            _geofencesController.add([]);
          },
        );
  }

  /// Get location name from coordinates
  Future<String> getLocationName(double latitude, double longitude) async {
    try {
      const String baseUrl = 'https://nominatim.openstreetmap.org/reverse';
      final String url =
          '$baseUrl?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

      debugPrint(
        '🌍 [MAP_SERVICE] Fetching location for: $latitude, $longitude',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter GPS App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] ?? 'Unknown Location';
        debugPrint('🌍 [MAP_SERVICE] Location found: $displayName');
        return displayName;
      } else {
        debugPrint(
          '❌ [MAP_SERVICE] Failed to get location: ${response.statusCode}',
        );
        return 'Location unavailable';
      }
    } catch (e) {
      debugPrint('❌ [MAP_SERVICE] Error getting location: $e');
      return 'Location unavailable';
    }
  }

  /// Switch to a different vehicle
  Future<String?> switchToVehicle(String vehicleId, String vehicleName) async {
    debugPrint(
      '🔄 [MAP_SERVICE] Switching to vehicle: $vehicleId ($vehicleName)',
    );

    // Cancel existing listeners
    _cancelAllListeners();

    // Clear streams
    _gpsDataController.add({});
    _vehicleStateController.add(false);
    _geofencesController.add([]);

    // Initialize new device
    final newDeviceId = await initializeDevice(vehicleId);

    if (newDeviceId != null) {
      // Start new listeners
      startDeviceDataListening(newDeviceId);
      loadGeofenceOverlayData(vehicleId);
    }

    return newDeviceId;
  }

  /// Cancel all active listeners
  void _cancelAllListeners() {
    _gpsListener?.cancel();
    _relayListener?.cancel();
    _geofenceListener?.cancel();
    debugPrint('🔧 [MAP_SERVICE] All listeners cancelled');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    debugPrint('🔧 [MAP_SERVICE] Disposing service...');

    _cancelAllListeners();
    _vehicleListener?.cancel();

    _gpsDataController.close();
    _vehicleStateController.close();
    _vehiclesController.close();
    _geofencesController.close();

    debugPrint('🔧 [MAP_SERVICE] Service disposed');
  }

  /// Utility method to check if GPS data is valid
  static bool isGPSDataValid(Map<String, dynamic> gpsData) {
    final latitude = gpsData['latitude'];
    final longitude = gpsData['longitude'];

    return latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0 &&
        latitude is num &&
        longitude is num;
  }

  /// Utility method to extract coordinates from GPS data
  static LatLng? getCoordinatesFromGPSData(Map<String, dynamic> gpsData) {
    if (!isGPSDataValid(gpsData)) return null;

    return LatLng(
      gpsData['latitude'].toDouble(),
      gpsData['longitude'].toDouble(),
    );
  }

  /// Utility method to format timestamp to WITA
  static String formatToWITA(DateTime dateTime) {
    // WITA is UTC+8
    final witaTime = dateTime.toUtc().add(const Duration(hours: 8));
    return '${witaTime.hour.toString().padLeft(2, '0')}:${witaTime.minute.toString().padLeft(2, '0')}:${witaTime.second.toString().padLeft(2, '0')} WITA';
  }
}

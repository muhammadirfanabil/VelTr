import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class mapServices {
  final String deviceId;

  mapServices({required this.deviceId});

  Future<bool> pingESP32(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/ping'))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('Timeout', 408),
          );

      if (response.statusCode == 200) {
        debugPrint("ESP32 responded: ${response.body}");
        return true;
      } else {
        debugPrint(
          "ESP32 not responding properly. Status: ${response.statusCode}",
        );
        return false;
      }
    } catch (e) {
      debugPrint("Error pinging ESP32: $e");
      return false;
    }
  }

  Future<String> fetchLocationName(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterApp', // User-Agent wajib diisi
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'Location Not Found';
      } else {
        return 'Failed to Load Location';
      }
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Get GPS data stream for the specific device
  Stream<Map<String, dynamic>?> getGPSDataStream() {
    final ref = FirebaseDatabase.instance.ref('devices/$deviceId/gps');
    return ref.onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // Get relay status stream for the specific device
  Stream<bool> getRelayStatusStream() {
    final ref = FirebaseDatabase.instance.ref('devices/$deviceId/relay');
    return ref.onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  // Get last GPS location for the device
  Future<Map<String, dynamic>?> getLastGPSLocation() async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/gps');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching last GPS location: $e");
      return null;
    }
  }

  // Toggle relay status for the device
  Future<void> toggleRelayStatus() async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/relay');
      final snapshot = await ref.get();

      bool currentStatus = false;
      if (snapshot.exists) {
        currentStatus = snapshot.value as bool? ?? false;
      }

      // Toggle the status
      await ref.set(!currentStatus);
      debugPrint("Relay status toggled to: ${!currentStatus}");
    } catch (e) {
      debugPrint("Error toggling relay status: $e");
    }
  }

  // Set relay status for the device
  Future<void> setRelayStatus(bool status) async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/relay');
      await ref.set(status);
      debugPrint("Relay status set to: $status");
    } catch (e) {
      debugPrint("Error setting relay status: $e");
    }
  }

  // Get current relay status for the device
  Future<bool> getCurrentRelayStatus() async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/relay');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        return snapshot.value as bool? ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("Error getting relay status: $e");
      return false;
    }
  }

  // Format GPS data for display
  Map<String, String> formatGPSData(Map<String, dynamic> gpsData) {
    return {
      'latitude': gpsData['latitude']?.toString() ?? 'N/A',
      'longitude': gpsData['longitude']?.toString() ?? 'N/A',
      'altitude': '${gpsData['altitude_m']?.toString() ?? 'N/A'} m',
      'speed': '${gpsData['speed_kmph']?.toString() ?? 'N/A'} km/h',
      'course': '${gpsData['course_deg']?.toString() ?? 'N/A'}°',
      'satellites': gpsData['satellites']?.toString() ?? 'N/A',
      'hdop': gpsData['hdop']?.toString() ?? 'N/A',
      'date': gpsData['tanggal']?.toString() ?? 'N/A',
      'time': gpsData['waktu_wita']?.toString() ?? 'N/A',
    };
  }

  // Check if GPS data is valid
  bool isGPSDataValid(Map<String, dynamic>? gpsData) {
    if (gpsData == null) return false;

    final lat = gpsData['latitude'];
    final lon = gpsData['longitude'];

    return lat != null &&
        lon != null &&
        lat is num &&
        lon is num &&
        lat != 0 &&
        lon != 0;
  }

  // Get all devices (for listing available devices)
  Stream<Map<String, dynamic>?> getAllDevicesStream() {
    final ref = FirebaseDatabase.instance.ref('devices');
    return ref.onValue.map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  // Get list of device IDs
  Future<List<String>> getDeviceIds() async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final devices = Map<String, dynamic>.from(snapshot.value as Map);
        return devices.keys.toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error getting device IDs: $e");
      return [];
    }
  }

  // Legacy method compatibility - fetches last location using new structure
  void fetchLastLocation(Function(Map<String, dynamic>?) callback) {
    getGPSDataStream().listen((gpsData) {
      callback(gpsData);
    });
  }

  // Legacy method compatibility - fetches relay status using new structure
  void fetchRelayStatus(Function(bool) callback) {
    getRelayStatusStream().listen((relayStatus) {
      callback(relayStatus);
    });
  }

  // Static method to create mapServices instance for a specific device
  static mapServices forDevice(String deviceId) {
    return mapServices(deviceId: deviceId);
  }

  // Get multiple devices GPS streams (for dashboard overview)
  static Stream<Map<String, Map<String, dynamic>>> getMultipleDevicesGPSStream(
    List<String> deviceIds,
  ) {
    if (deviceIds.isEmpty) {
      return Stream.value({});
    }

    final deviceStreams = deviceIds.map((deviceId) {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/gps');
      return ref.onValue.map((event) {
        if (event.snapshot.exists) {
          return MapEntry(
            deviceId,
            Map<String, dynamic>.from(event.snapshot.value as Map),
          );
        }
        return MapEntry(deviceId, <String, dynamic>{});
      });
    });

    // Combine all streams into a single stream
    return Stream.fromIterable(deviceStreams).asyncMap((stream) async {
      final result = <String, Map<String, dynamic>>{};
      await for (final entry in stream) {
        result[entry.key] = entry.value;
      }
      return result;
    });
  }

  // Static method to get GPS data for user's devices
  static Stream<Map<String, Map<String, dynamic>>> getUserDevicesGPSStream(
    List<String> deviceIds,
  ) {
    return getMultipleDevicesGPSStream(deviceIds);
  }

  // Update device GPS data in Firebase Realtime Database (for ESP32 integration)
  Future<void> updateDeviceGPSData(Map<String, dynamic> gpsData) async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/gps');
      await ref.set(gpsData);
      debugPrint("GPS data updated for device $deviceId");
    } catch (e) {
      debugPrint("Error updating GPS data: $e");
    }
  }

  // Sync device status with Firebase Realtime Database
  Future<void> syncDeviceStatus(bool isActive) async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceId/status');
      await ref.set({
        'isActive': isActive,
        'lastSeen': DateTime.now().toIso8601String(),
      });
      debugPrint("Device status synced for device $deviceId");
    } catch (e) {
      debugPrint("Error syncing device status: $e");
    }
  }

  // USER LOCATION FUNCTIONALITY
  /// Checks if location services are enabled and permissions are granted
  static Future<bool> isLocationServiceAvailable() async {
    debugPrint('🗺️ [MAPSERVICE] Checking location service availability...');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('🗺️ [MAPSERVICE] Location service enabled: $serviceEnabled');

    if (!serviceEnabled) {
      debugPrint('🗺️ [MAPSERVICE] ❌ Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('🗺️ [MAPSERVICE] Current permission status: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint(
        '🗺️ [MAPSERVICE] Permission denied, requesting permission...',
      );
      permission = await Geolocator.requestPermission();
      debugPrint('🗺️ [MAPSERVICE] Permission after request: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('🗺️ [MAPSERVICE] ❌ Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '🗺️ [MAPSERVICE] ❌ Location permissions are permanently denied',
      );
      return false;
    }

    debugPrint('🗺️ [MAPSERVICE] ✅ Location service is available');
    return true;
  }

  /// Gets the current user location
  static Future<LatLng?> getCurrentUserLocation() async {
    debugPrint('🗺️ [MAPSERVICE] Getting current user location...');

    try {
      if (!await isLocationServiceAvailable()) {
        debugPrint('🗺️ [MAPSERVICE] ❌ Location service not available');
        return null;
      }

      debugPrint('🗺️ [MAPSERVICE] Requesting position from GPS...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      debugPrint(
        '🗺️ [MAPSERVICE] ✅ User location obtained: ${position.latitude}, ${position.longitude}',
      );
      debugPrint(
        '🗺️ [MAPSERVICE] Location details - Accuracy: ${position.accuracy}m, Altitude: ${position.altitude}m',
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('🗺️ [MAPSERVICE] ❌ Failed to get current location: $e');
      return null;
    }
  }

  /// Gets a stream of user location updates
  static Stream<LatLng?> getUserLocationStream() {
    debugPrint('🗺️ [MAPSERVICE] Starting user location stream...');

    return Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Only update when user moves 10 meters
            timeLimit: Duration(seconds: 30), // Timeout after 30 seconds
          ),
        )
        .map((Position position) {
          debugPrint(
            '🗺️ [MAPSERVICE] 📍 Location stream update: ${position.latitude}, ${position.longitude}',
          );
          debugPrint(
            '🗺️ [MAPSERVICE] Stream details - Accuracy: ${position.accuracy}m, Speed: ${position.speed}m/s',
          );
          return LatLng(position.latitude, position.longitude);
        })
        .handleError((error) {
          debugPrint('🗺️ [MAPSERVICE] ❌ Location stream error: $error');
          return null;
        });
  }

  /// Creates a marker for the user's current location
  static Marker? getUserLocationMarker(LatLng? userLocation) {
    if (userLocation == null) {
      debugPrint(
        '🗺️ [MAPSERVICE] ❌ Cannot create user location marker - location is null',
      );
      return null;
    }

    debugPrint(
      '🗺️ [MAPSERVICE] ✅ Creating user location marker for: ${userLocation.latitude}, ${userLocation.longitude}',
    );

    return Marker(
      point: userLocation,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  /// Creates a circle layer showing location accuracy
  static CircleMarker? getUserLocationAccuracyCircle(
    LatLng? userLocation, {
    double? accuracy,
  }) {
    if (userLocation == null) return null;

    return CircleMarker(
      point: userLocation,
      radius: accuracy ?? 50.0,
      color: Colors.blue.withOpacity(0.1),
      borderColor: Colors.blue.withOpacity(0.3),
      borderStrokeWidth: 1,
    );
  }

  /// Centers the map on user location with smooth animation
  static Future<void> centerMapOnUser(
    MapController mapController, {
    double zoom = 16.0,
  }) async {
    final userLocation = await getCurrentUserLocation();
    if (userLocation != null) {
      mapController.move(userLocation, zoom);
      debugPrint(
        '🗺️ [MAP_CENTER] Centered map on user location: ${userLocation.latitude}, ${userLocation.longitude}',
      );
    } else {
      debugPrint(
        '🗺️ [MAP_CENTER] Cannot center on user location: location not available',
      );
    }
  }

  /// Centers the map on device location with smooth animation
  static void centerMapOnDevice(
    MapController mapController,
    LatLng deviceLocation, {
    double zoom = 16.0,
  }) {
    mapController.move(deviceLocation, zoom);
    debugPrint(
      '🗺️ [MAP_CENTER] Centered map on device location: ${deviceLocation.latitude}, ${deviceLocation.longitude}',
    );
  }
}

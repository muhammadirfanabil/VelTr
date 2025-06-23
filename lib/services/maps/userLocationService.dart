import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Service class for handling user location functionality
/// Provides methods for getting user location, creating location markers,
/// and managing location permissions and services
class UserLocationService {
  static UserLocationService? _instance;
  StreamSubscription<Position>? _locationSubscription;
  LatLng? _lastKnownLocation;
  bool _isTracking = false;

  // Singleton pattern
  static UserLocationService get instance {
    _instance ??= UserLocationService._internal();
    return _instance!;
  }

  UserLocationService._internal();

  /// Gets the last known user location without requesting a new one
  LatLng? get lastKnownLocation => _lastKnownLocation;

  /// Returns true if location tracking is currently active
  bool get isTracking => _isTracking;

  /// Checks if location services are enabled and permissions are granted
  Future<bool> isLocationServiceAvailable() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('🗺️ [LOCATION_SERVICE] Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('🗺️ [LOCATION_SERVICE] Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '🗺️ [LOCATION_SERVICE] Location permissions are permanently denied',
      );
      return false;
    }

    return true;
  }

  /// Gets the current user location (one-time request)
  Future<LatLng?> getCurrentUserLocation() async {
    try {
      if (!await isLocationServiceAvailable()) {
        return _lastKnownLocation;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      _lastKnownLocation = LatLng(position.latitude, position.longitude);
      debugPrint(
        '🗺️ [USER_LOCATION] User location obtained: ${position.latitude}, ${position.longitude}',
      );
      return _lastKnownLocation;
    } catch (e) {
      debugPrint('🗺️ [USER_LOCATION] Failed to get current location: $e');
      return _lastKnownLocation;
    }
  }

  /// Starts continuous location tracking
  Stream<LatLng?> startLocationTracking() async* {
    if (!await isLocationServiceAvailable()) {
      yield _lastKnownLocation;
      return;
    }

    _isTracking = true;
    debugPrint('🗺️ [USER_LOCATION] Starting location tracking...');

    try {
      await for (Position position in Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Only update when user moves 10 meters
          timeLimit: Duration(seconds: 30), // Timeout after 30 seconds
        ),
      )) {
        _lastKnownLocation = LatLng(position.latitude, position.longitude);
        debugPrint(
          '🗺️ [USER_LOCATION_STREAM] Location update: ${position.latitude}, ${position.longitude}',
        );
        yield _lastKnownLocation;
      }
    } catch (e) {
      debugPrint('🗺️ [USER_LOCATION_STREAM] Error: $e');
      yield _lastKnownLocation;
    } finally {
      _isTracking = false;
    }
  }

  /// Stops location tracking
  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
    debugPrint('🗺️ [USER_LOCATION] Location tracking stopped');
  }

  /// Creates a marker for the user's current location
  Marker? getUserLocationMarker(LatLng? userLocation) {
    final location = userLocation ?? _lastKnownLocation;
    if (location == null) return null;

    return Marker(
      point: location,
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
  CircleMarker? getUserLocationAccuracyCircle(
    LatLng? userLocation, {
    double? accuracy,
  }) {
    final location = userLocation ?? _lastKnownLocation;
    if (location == null) return null;

    return CircleMarker(
      point: location,
      radius: accuracy ?? 50.0,
      color: Colors.blue.withOpacity(0.1),
      borderColor: Colors.blue.withOpacity(0.3),
      borderStrokeWidth: 1,
    );
  }

  /// Centers the map on user location with smooth animation
  Future<bool> centerMapOnUser(
    MapController mapController, {
    double zoom = 16.0,
  }) async {
    LatLng? userLocation = _lastKnownLocation;

    // Try to get fresh location if we don't have one
    if (userLocation == null) {
      userLocation = await getCurrentUserLocation();
    }

    if (userLocation != null) {
      mapController.move(userLocation, zoom);
      debugPrint(
        '🗺️ [MAP_CENTER] Centered map on user location: ${userLocation.latitude}, ${userLocation.longitude}',
      );
      return true;
    } else {
      debugPrint(
        '🗺️ [MAP_CENTER] Cannot center on user location: location not available',
      );
      return false;
    }
  }

  /// Disposes of resources when the service is no longer needed
  void dispose() {
    stopLocationTracking();
    _lastKnownLocation = null;
    debugPrint('🗺️ [USER_LOCATION] UserLocationService disposed');
  }
}

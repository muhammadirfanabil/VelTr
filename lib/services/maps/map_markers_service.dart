import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

/// Service for creating reusable map markers with consistent styling
/// Used across geofence screens for user and device location markers
class MapMarkersService {
  /// Creates a user location marker (blue dot)
  ///
  /// [userLocation] - The user's current location
  /// [size] - Optional size for the marker (defaults to 20.0)
  ///
  /// Returns a MarkerLayer with the user location marker
  static MarkerLayer createUserLocationMarker(
    LatLng userLocation, {
    double size = 20.0,
  }) {
    return MarkerLayer(
      markers: [
        Marker(
          point: userLocation,
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundPrimary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Creates a device location marker with GPS icon
  ///
  /// [deviceLocation] - The device's current location
  /// [isLoading] - Whether the device location is still loading
  /// [deviceName] - Optional device name for tooltip
  /// [size] - Optional size for the marker (defaults to 40.0)
  ///
  /// Returns a MarkerLayer with the device location marker
  static MarkerLayer createDeviceLocationMarker(
    LatLng deviceLocation, {
    bool isLoading = false,
    String? deviceName,
    double size = 40.0,
  }) {
    return MarkerLayer(
      markers: [
        Marker(
          point: deviceLocation,
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring for better visibility
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warning, width: 2),
                ),
              ),
              // Inner device marker
              Container(
                width: size * 0.6, // 60% of outer size
                height: size * 0.6,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundPrimary,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  AppIcons.gps,
                  color: AppColors.backgroundPrimary,
                  size: size * 0.35, // 35% of outer size
                ),
              ),
              // Loading indicator overlay
              if (isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: size * 0.4, // 40% of outer size
                        height: size * 0.4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Creates geofence polygon point markers (numbered circles)
  ///
  /// [polygonPoints] - List of polygon points
  /// [color] - Color for the markers (defaults to AppColors.accentRed)
  /// [size] - Size of the markers (defaults to 40.0)
  ///
  /// Returns a MarkerLayer with numbered polygon point markers
  static MarkerLayer createPolygonPointMarkers(
    List<LatLng> polygonPoints, {
    Color? color,
    double size = 40.0,
  }) {
    final markerColor = color ?? AppColors.accentRed;

    return MarkerLayer(
      markers:
          polygonPoints.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final point = entry.value;

            return Marker(
              point: point,
              width: size,
              height: size,
              child: Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: size * 0.35, // 35% of marker size
                      color: AppColors.backgroundPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  /// Creates a custom marker with icon
  ///
  /// [location] - The marker location
  /// [icon] - The icon to display
  /// [color] - Background color for the marker
  /// [size] - Size of the marker (defaults to 32.0)
  /// [iconSize] - Size of the icon (defaults to 18.0)
  ///
  /// Returns a MarkerLayer with the custom marker
  static MarkerLayer createCustomMarker(
    LatLng location,
    IconData icon, {
    Color? color,
    double size = 32.0,
    double? iconSize,
  }) {
    final markerColor = color ?? AppColors.primaryBlue;
    final iconSizeValue = iconSize ?? size * 0.5;

    return MarkerLayer(
      markers: [
        Marker(
          point: location,
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundPrimary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.backgroundPrimary,
              size: iconSizeValue,
            ),
          ),
        ),
      ],
    );
  }

  /// Calculates optimal map center between multiple locations
  ///
  /// [locations] - List of locations to include in calculation
  ///
  /// Returns the center point of all locations
  static LatLng calculateCenterPoint(List<LatLng> locations) {
    if (locations.isEmpty) {
      throw ArgumentError('Cannot calculate center of empty location list');
    }

    if (locations.length == 1) {
      return locations.first;
    }

    double totalLat = 0;
    double totalLng = 0;

    for (final location in locations) {
      totalLat += location.latitude;
      totalLng += location.longitude;
    }

    return LatLng(totalLat / locations.length, totalLng / locations.length);
  }

  /// Calculates optimal zoom level for showing multiple locations
  ///
  /// [locations] - List of locations to fit in view
  /// [defaultZoom] - Default zoom if calculation fails (defaults to 14.0)
  ///
  /// Returns optimal zoom level
  static double calculateOptimalZoom(
    List<LatLng> locations, {
    double defaultZoom = 14.0,
  }) {
    if (locations.length <= 1) {
      return defaultZoom;
    }

    try {
      // Calculate distance between furthest points
      double maxDistance = 0;
      for (int i = 0; i < locations.length; i++) {
        for (int j = i + 1; j < locations.length; j++) {
          final distance = _calculateDistance(locations[i], locations[j]);
          if (distance > maxDistance) {
            maxDistance = distance;
          }
        }
      }

      // Determine zoom based on max distance (rough approximation)
      if (maxDistance > 10000) return 10.0; // > 10km
      if (maxDistance > 5000) return 12.0; // > 5km
      if (maxDistance > 1000) return 14.0; // > 1km
      if (maxDistance > 500) return 15.0; // > 500m
      return 16.0; // < 500m
    } catch (e) {
      debugPrint('Error calculating optimal zoom: $e');
      return defaultZoom;
    }
  }

  /// Helper method to calculate distance between two points in meters
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}

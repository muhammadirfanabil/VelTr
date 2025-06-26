import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/Geofence/Geofence.dart';
import '../motoricon.dart';
import '../../theme/app_colors.dart';

class MapOverlayLayer extends StatelessWidget {
  final List<Geofence> geofences;
  final bool showGeofences;
  final bool hasGPSData;
  final LatLng? vehicleLocation;
  final bool isVehicleOn;
  final VoidCallback onVehicleTap;

  const MapOverlayLayer({
    Key? key,
    required this.geofences,
    required this.showGeofences,
    required this.hasGPSData,
    required this.vehicleLocation,
    required this.isVehicleOn,
    required this.onVehicleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Modern, minimalist theme colors
    final geofenceColor = AppColors.primaryBlue.withValues(alpha: 0.18);
    final geofenceBorderColor = AppColors.primaryBlue;
    final labelBgColor = AppColors.primaryBlue.withValues(alpha: 0.92);
    final labelTextColor = Colors.white;
    final pointColor = AppColors.primaryBlue.withValues(alpha: 0.77);

    return Stack(
      children: [
        // --- Geofence polygons ---
        if (showGeofences && geofences.isNotEmpty)
          PolygonLayer(
            polygons:
                geofences
                    .where((geofence) => geofence.points.length >= 3)
                    .map(
                      (geofence) => Polygon(
                        points:
                            geofence.points
                                .map(
                                  (point) =>
                                      LatLng(point.latitude, point.longitude),
                                )
                                .toList(),
                        color: geofenceColor,
                        borderColor: geofenceBorderColor,
                        borderStrokeWidth: 2.2,
                      ),
                    )
                    .toList(),
          ),

        // --- Geofence labels ---
        if (showGeofences && geofences.isNotEmpty)
          MarkerLayer(
            markers:
                geofences.where((geofence) => geofence.points.length >= 3).map((
                  geofence,
                ) {
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
                    width: 104,
                    height: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: labelBgColor,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          geofence.name,
                          style: TextStyle(
                            color: labelTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            letterSpacing: -0.1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),

        // --- Geofence corner points ---
        if (showGeofences && geofences.isNotEmpty)
          CircleLayer(
            circles:
                geofences
                    .where((geofence) => geofence.points.length >= 3)
                    .expand(
                      (geofence) => geofence.points.map(
                        (point) => CircleMarker(
                          point: LatLng(point.latitude, point.longitude),
                          radius: 5.5,
                          color: pointColor,
                          useRadiusInMeter: false,
                          borderStrokeWidth: 1.3,
                          borderColor: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
          ),

        // --- Vehicle marker ---
        if (hasGPSData && vehicleLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: vehicleLocation!,
                width: 70,
                height: 70,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onVehicleTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.23,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: VehicleMarkerIcon(isOn: isVehicleOn),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/Geofence/Geofence.dart';
import '../motoricon.dart';

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
    return Stack(
      children: [
        // Geofence polygons
        if (showGeofences && geofences.isNotEmpty)
          PolygonLayer(
            polygons:
                geofences.where((geofence) => geofence.points.length >= 3).map((
                  geofence,
                ) {
                  return Polygon(
                    points:
                        geofence.points
                            .map(
                              (point) =>
                                  LatLng(point.latitude, point.longitude),
                            )
                            .toList(),
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 3,
                  );
                }).toList(),
          ),

        // Geofence labels
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
                        border: Border.all(color: Colors.white, width: 2),
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
                }).toList(),
          ),

        // Geofence corner points
        if (showGeofences && geofences.isNotEmpty)
          CircleLayer(
            circles:
                geofences
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

        // Vehicle marker
        if (hasGPSData && vehicleLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: vehicleLocation!,
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: onVehicleTap,
                  child: VehicleMarkerIcon(isOn: isVehicleOn),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

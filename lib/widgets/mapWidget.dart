import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Make sure this is imported

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  LatLng? userLatLng;
  double zoomLevel = 15.0;

  @override
  void initState() {
    super.initState();
    fetchRealtimeLocation();
  }

  void fetchRealtimeLocation() {
    final ref = FirebaseDatabase.instance.ref('GPS');

    ref.onValue.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = double.tryParse(data['latitude'].toString());
      final lng = double.tryParse(data['longitude'].toString());

      if (lat != null && lng != null) {
        final newPosition = LatLng(lat, lng);
        setState(() {
          userLatLng = newPosition;
        });

        _mapController.move(newPosition, zoomLevel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return userLatLng == null
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng!,
            initialZoom: zoomLevel,
            onPositionChanged: (position, _) {
              setState(() {
                zoomLevel = position.zoom;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.gps_app',
            ),

            MarkerLayer(
              markers: [
                Marker(
                  point: userLatLng!,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              content: const Text('Track'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/motor.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
  }
}

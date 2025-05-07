import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  LatLng? userLatLng;

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
        _mapController.move(newPosition, _mapController.camera.zoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return userLatLng == null
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: userLatLng!, initialZoom: 15.0),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.gps_app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: userLatLng!,
                  width: 80.0,
                  height: 80.0,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        );
  }
}

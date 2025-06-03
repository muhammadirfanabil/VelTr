import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapWidget extends StatefulWidget {
  final MapOptions options;
  final List<Widget> children;
  final String? deviceId; // Made this configurable

  const MapWidget({
    super.key,
    required this.options,
    required this.children,
    this.deviceId = 'B0A7322B2EC4', // Default value
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  StreamSubscription<DatabaseEvent>? _locationSubscription;

  LatLng? userLatLng;

  @override
  void initState() {
    super.initState();
    fetchRealtimeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (mounted) {
      setState(() {
        currentZoom = _mapController.camera.zoom;
      });
    }
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Flutter_GPS_Tracker/1.0 (contact@example.com)',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] as String?;
      } else {
        debugPrint(
          'Reverse geocode failed with status: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      return null;
    }
  }

  void fetchRealtimeLocation() {
    final ref = FirebaseDatabase.instance.ref('GPS');

      _locationSubscription = ref.onValue.listen(
        (event) async {
          if (!mounted) return;

          final snapshotValue = event.snapshot.value;
          if (snapshotValue == null) {
            setState(() {
              _errorMessage = 'No GPS data available';
              _isLoading = false;
            });
            return;
          }

          try {
            final data = Map<String, dynamic>.from(
              snapshotValue as Map<Object?, Object?>,
            );

            final lat = double.tryParse(data['latitude']?.toString() ?? '');
            final lng = double.tryParse(data['longitude']?.toString() ?? '');
            final updated = data['lastUpdated']?.toString();
            final status = data['isVehicleOn'] == true;

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
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: userLatLng!, initialZoom: 15.0),
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

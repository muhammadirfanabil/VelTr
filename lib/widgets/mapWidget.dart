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
  String? locationName;
  String? lastUpdated;
  bool isVehicleOn = false;
  double currentZoom = 15.0;
  bool _isLoading = true;
  String? _errorMessage;

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
    try {
      final ref = FirebaseDatabase.instance.ref(
        'devices/${widget.deviceId}/gps',
      );

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

              String? placeName = locationName;
              if (userLatLng == null ||
                  _calculateDistance(userLatLng!, newPosition) > 50) {
                placeName = await reverseGeocode(lat, lng);
              }

              if (!mounted) return;

              setState(() {
                userLatLng = newPosition;
                locationName = placeName ?? locationName ?? 'Unknown location';
                lastUpdated = updated;
                isVehicleOn = status;
                _isLoading = false;
                _errorMessage = null;
              });

              if (_calculateDistance(
                    _mapController.camera.center,
                    newPosition,
                  ) >
                  10) {
                _mapController.move(newPosition, currentZoom);
              }
            } else {
              setState(() {
                _errorMessage = 'Invalid GPS coordinates';
                _isLoading = false;
              });
            }
          } catch (e) {
            debugPrint('Error parsing GPS data: $e');
            setState(() {
              _errorMessage = 'Error parsing GPS data';
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          debugPrint('Firebase listener error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Connection error: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error setting up Firebase listener: $e');
      setState(() {
        _errorMessage = 'Failed to connect to GPS data';
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.options.initialCenter,
            initialZoom: widget.options.initialZoom,
            minZoom: widget.options.minZoom,
            maxZoom: widget.options.maxZoom,
            initialRotation: widget.options.initialRotation,
            keepAlive: widget.options.keepAlive,
            onMapEvent: _onMapEvent,
            onTap: widget.options.onTap,
          ),
          children: [
            ...widget.children, // Each page can add its own layers/markers
          ],
        ),
        // Loading indicator
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        // Error message
        if (_errorMessage != null)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

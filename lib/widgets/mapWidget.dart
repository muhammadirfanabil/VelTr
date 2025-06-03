import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapWidget extends StatefulWidget {
  final MapController? mapController;
  final MapOptions? options;
  final LatLng? initialCenter;
  final double initialZoom;
  final double? minZoom;
  final double? maxZoom;
  final double? initialRotation;
  final bool? keepAlive;
  final Function(TapPosition, LatLng)? onTap;
  final List<Widget> children;
  final String? deviceId;

  const MapWidget({
    Key? key,
    this.mapController,
    this.options,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.minZoom,
    this.maxZoom,
    this.initialRotation,
    this.keepAlive,
    this.onTap,
    required this.children,
    this.deviceId,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late MapController _mapController;
  StreamSubscription<DatabaseEvent>? _locationSubscription;

  LatLng? userLatLng;
  String? locationName;
  String? lastUpdated;
  bool isVehicleOn = false;
  double currentZoom = 15.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    currentZoom = widget.initialZoom;

    // Only fetch realtime location if deviceId is provided
    if (widget.deviceId != null) {
      fetchRealtimeLocation();
    }
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
    if (widget.deviceId == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final ref = FirebaseDatabase.instance.ref(
        'devices/${widget.deviceId}/gpsData',
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
            final updated =
                data['tanggal']
                    ?.toString(); // Changed from lastUpdated to tanggal to match your Firebase structure
            final status =
                data['isActive'] ==
                true; // Changed to match your Firebase structure

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

              // Only move map if it's far from current position
              if (_calculateDistance(
                    _mapController.camera.center,
                    newPosition,
                  ) >
                  100) {
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
          options:
              widget.options ??
              MapOptions(
                initialCenter:
                    widget.initialCenter ?? const LatLng(-2.2180, 113.9220),
                initialZoom: widget.initialZoom,
                minZoom: widget.minZoom ?? 3.0,
                maxZoom: widget.maxZoom ?? 18.0,
                initialRotation: widget.initialRotation ?? 0.0,
                keepAlive: widget.keepAlive ?? false,
                onMapEvent: _onMapEvent,
                onTap: widget.onTap,
              ),
          children: [...widget.children],
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/maps/mapsService.dart';

class MapWidget extends StatefulWidget {
  final String? deviceId; // Make deviceId configurable

  const MapWidget({super.key, this.deviceId});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  late final mapServices _mapService;
  LatLng? userLatLng;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    // Use provided deviceId or default
    final deviceId = widget.deviceId ?? 'B0A7322B2EC4';
    _mapService = mapServices(deviceId: deviceId);
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // First, try to get the last known location
      final gpsData = await _mapService.getLastGPSLocation();
      if (gpsData != null && _mapService.isGPSDataValid(gpsData)) {
        final lat = gpsData['latitude'] as double;
        final lng = gpsData['longitude'] as double;
        if (mounted) {
          setState(() {
            userLatLng = LatLng(lat, lng);
            isLoading = false;
          });
        }
      }

      // Then start listening for real-time updates
      _startRealtimeTracking();
    } catch (e) {
      debugPrint('Error initializing map: $e');
      if (mounted) {
        setState(() {
          error = 'Failed to load GPS data: $e';
          isLoading = false;
        });
      }
    }
  }

  void _startRealtimeTracking() {
    _mapService.getGPSDataStream().listen(
      (gpsData) {
        if (gpsData != null && _mapService.isGPSDataValid(gpsData)) {
          final lat = gpsData['latitude'] as double;
          final lng = gpsData['longitude'] as double;
          final newPosition = LatLng(lat, lng);

          if (mounted) {
            setState(() {
              userLatLng = newPosition;
              isLoading = false;
              error = null;
            });

            // Move map to new position (optional - you might want to make this configurable)
            if (_mapController.camera.center.latitude == 0 &&
                _mapController.camera.center.longitude == 0) {
              // Only auto-move if map hasn't been manually moved
              _mapController.move(newPosition, _mapController.camera.zoom);
            }
          }
        }
      },
      onError: (e) {
        debugPrint('Error in GPS stream: $e');
        if (mounted) {
          setState(() {
            error = 'GPS tracking error: $e';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading GPS data...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Map Error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  error = null;
                });
                _initializeMap();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (userLatLng == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No GPS data available'),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userLatLng!,
        initialZoom: 15.0,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.gps_app',
          maxZoom: 18,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: userLatLng!,
              width: 40.0,
              height: 40.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.motorcycle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

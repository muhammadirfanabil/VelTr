import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/maps/mapsService.dart';

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
  final bool autoFollow; // New parameter for automatic following
  final double followThreshold; // Distance threshold for auto-follow (meters)

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
    this.autoFollow = true,
    this.followThreshold = 50.0, // Auto-follow when device moves 50+ meters
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  late MapController _mapController;
  mapServices? _mapService;
  StreamSubscription? _gpsSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  LatLng? userLatLng;
  bool isLoading = true;
  String? error;
  double currentZoom = 15.0;
  double? gpsAccuracy; // GPS accuracy in meters
  // Auto-follow state management
  bool _isFollowing = true; // Start with following enabled
  bool _userInteracted = false; // Track if user manually moved the map
  DateTime? _lastUserInteraction;
  Timer? _resumeFollowingTimer;
  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    currentZoom = widget.initialZoom;

    // Initialize pulse animation for the vehicle marker
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Initialize map service if deviceId is provided
    if (widget.deviceId != null) {
      _mapService = mapServices(deviceId: widget.deviceId!);
      _initializeMap();
    } else {
      // If no deviceId, just show the map without GPS tracking
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _pulseController.dispose();
    _resumeFollowingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (_mapService == null) return;

    try {
      // First, try to get the last known location
      final gpsData = await _mapService!.getLastGPSLocation();
      if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
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
    if (_mapService == null) return;

    _gpsSubscription = _mapService!.getGPSDataStream().listen(
      (gpsData) {
        if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
          final lat = gpsData['latitude'] as double;
          final lng = gpsData['longitude'] as double;
          final accuracy = gpsData['accuracy'] as double?;
          final newPosition = LatLng(lat, lng);

          if (mounted) {
            final previousPosition = userLatLng;
            setState(() {
              userLatLng = newPosition;
              gpsAccuracy = accuracy;
              isLoading = false;
              error = null;
            });

            // Auto-follow logic
            if (widget.autoFollow && _isFollowing) {
              final currentCenter = _mapController.camera.center;
              bool shouldMove = false;

              // Always move on first location
              if (previousPosition == null) {
                shouldMove = true;
              } else {
                // Calculate distance from current map center to new position
                final distanceFromCenter = _calculateDistance(
                  currentCenter,
                  newPosition,
                );

                // Move if device moved beyond threshold or is far from center
                if (distanceFromCenter > widget.followThreshold) {
                  shouldMove = true;
                }
              }

              if (shouldMove) {
                _moveToPosition(newPosition, currentZoom);
              }
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

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Simple distance calculation using Haversine formula
    const double earthRadius = 6371000; // meters
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  void _onMapEvent(MapEvent mapEvent) {
    // Track user interactions to temporarily disable auto-follow
    if (mapEvent is MapEventMoveStart) {
      _handleUserInteraction();
    } else if (mapEvent is MapEventScrollWheelZoom) {
      _handleUserInteraction();
    }

    // Update current zoom level
    if (mapEvent is MapEventMove) {
      currentZoom = mapEvent.camera.zoom;
    }
  }

  void _handleUserInteraction() {
    setState(() {
      _userInteracted = true;
      _isFollowing = false;
      _lastUserInteraction = DateTime.now();
    });

    // Cancel existing timer
    _resumeFollowingTimer?.cancel();

    // Resume auto-follow after 10 seconds of no interaction
    _resumeFollowingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isFollowing = widget.autoFollow;
          _userInteracted = false;
        });
      }
    });
  }

  void _moveToPosition(LatLng position, double zoom, {bool animated = true}) {
    if (animated) {
      // Smooth transition to new position
      _mapController.move(position, zoom);
    } else {
      _mapController.move(position, zoom);
    }
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
    } // Determine the center for the map
    LatLng mapCenter =
        widget.initialCenter ??
        userLatLng ??
        const LatLng(-2.2180, 113.9220); // Default Indonesia center

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options:
              widget.options ??
              MapOptions(
                initialCenter: mapCenter,
                initialZoom: widget.initialZoom,
                minZoom: widget.minZoom ?? 3.0,
                maxZoom: widget.maxZoom ?? 18.0,
                initialRotation: widget.initialRotation ?? 0.0,
                keepAlive: widget.keepAlive ?? false,
                onMapEvent: _onMapEvent,
                onTap: widget.onTap,
              ),
          children: [
            // Default tile layer if no children provided
            if (widget.children.isEmpty)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.gps_app',
                maxZoom: 18,
              ),
            // Custom children from parent widget
            ...widget
                .children, // Add GPS marker if we have location data and deviceId was provided
            if (userLatLng != null && widget.deviceId != null)
              MarkerLayer(
                markers: [
                  // Accuracy circle (if accuracy data is available)
                  if (gpsAccuracy != null &&
                      gpsAccuracy! > 0 &&
                      gpsAccuracy! < 100)
                    Marker(
                      point: userLatLng!,
                      width: (gpsAccuracy! * 2).clamp(20.0, 200.0),
                      height: (gpsAccuracy! * 2).clamp(20.0, 200.0),
                      alignment: Alignment.center,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  // Main vehicle marker with pulse animation
                  Marker(
                    point: userLatLng!,
                    width: 24.0,
                    height: 24.0,
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 24.0,
                            height: 24.0,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                child: Image.asset(
                                  'assets/icons/motor.png',
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to motorcycle icon if asset fails to load
                                    return const Icon(
                                      Icons.motorcycle,
                                      color: Colors.blue,
                                      size: 12,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
        // Auto-follow control button
        if (widget.deviceId != null && userLatLng != null && !_isFollowing)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _isFollowing = true;
                  _userInteracted = false;
                });
                _resumeFollowingTimer?.cancel();
                _moveToPosition(userLatLng!, currentZoom);
              },
              backgroundColor: Colors.blue,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }
}

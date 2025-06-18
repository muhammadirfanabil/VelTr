import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/maps/mapsService.dart';

class MapWidget extends StatefulWidget {
  final MapController? mapController;
  final MapOptions? options;
  final LatLng? initialCenter;
  final double initialZoom;
  final double? minZoom;
  final double? maxZoom;
  final Function(TapPosition, LatLng)? onTap;
  final List<Widget> children;
  final String? deviceId;
  final bool autoFollow;
  final double followThreshold;

  const MapWidget({
    Key? key,
    this.mapController,
    this.options,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.minZoom,
    this.maxZoom,
    this.onTap,
    required this.children,
    this.deviceId,
    this.autoFollow = true,
    this.followThreshold = 50.0,
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
  double? gpsAccuracy;
  bool _isFollowing = true;
  Timer? _resumeFollowingTimer;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    currentZoom = widget.initialZoom;
    _initializePulseAnimation();

    if (widget.deviceId != null) {
      _mapService = mapServices(deviceId: widget.deviceId!);
      _initializeMap();
    } else {
      setState(() => isLoading = false);
    }
  }

  void _initializePulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
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
      final gpsData = await _mapService!.getLastGPSLocation();
      if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        _updateUserLocation(gpsData);
      }
      _startRealtimeTracking();
    } catch (e) {
      _handleError('Failed to load GPS data: $e');
    }
  }

  void _updateUserLocation(Map<String, dynamic> gpsData) {
    final lat = gpsData['latitude'] as double;
    final lng = gpsData['longitude'] as double;
    if (mounted) {
      setState(() {
        userLatLng = LatLng(lat, lng);
        isLoading = false;
      });
    }
  }

  void _handleError(String errorMessage) {
    debugPrint('MapWidget Error: $errorMessage');
    if (mounted) {
      setState(() {
        error = errorMessage;
        isLoading = false;
      });
    }
  }

  void _startRealtimeTracking() {
    if (_mapService == null) return;

    _gpsSubscription = _mapService!.getGPSDataStream().listen((gpsData) {
      if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        _processGPSUpdate(gpsData);
      }
    }, onError: (e) => _handleError('GPS tracking error: $e'));
  }

  void _processGPSUpdate(Map<String, dynamic> gpsData) {
    final lat = gpsData['latitude'] as double;
    final lng = gpsData['longitude'] as double;
    final accuracy = gpsData['accuracy'] as double?;
    final newPosition = LatLng(lat, lng);
    if (mounted) {
      setState(() {
        userLatLng = newPosition;
        gpsAccuracy = accuracy;
        isLoading = false;
        error = null;
      });

      if (widget.autoFollow && _isFollowing && _shouldMoveMap(newPosition)) {
        _mapController.move(newPosition, currentZoom);
      }
    }
  }

  bool _shouldMoveMap(LatLng newPosition) {
    return userLatLng == null ||
        _calculateDistance(_mapController.camera.center, newPosition) >
            widget.followThreshold;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  void _onMapEvent(MapEvent mapEvent) {
    if (mapEvent is MapEventMoveStart || mapEvent is MapEventScrollWheelZoom) {
      _handleUserInteraction();
    }
    if (mapEvent is MapEventMove) {
      currentZoom = mapEvent.camera.zoom;
    }
  }

  void _handleUserInteraction() {
    setState(() => _isFollowing = false);
    _resumeFollowingTimer?.cancel();
    _resumeFollowingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isFollowing = widget.autoFollow);
    });
  }

  Widget _buildVehicleMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder:
          (context, child) => Transform.scale(
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
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.motorcycle,
                          color: Colors.blue,
                          size: 12,
                        ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  List<Marker> _buildMarkers() {
    if (userLatLng == null || widget.deviceId == null) return [];

    final markers = <Marker>[];

    // Accuracy circle
    if (gpsAccuracy != null && gpsAccuracy! > 0 && gpsAccuracy! < 100) {
      markers.add(
        Marker(
          point: userLatLng!,
          width: (gpsAccuracy! * 2).clamp(20.0, 200.0),
          height: (gpsAccuracy! * 2).clamp(20.0, 200.0),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
          ),
        ),
      );
    }

    // Vehicle marker
    markers.add(
      Marker(
        point: userLatLng!,
        width: 24.0,
        height: 24.0,
        alignment: Alignment.center,
        child: _buildVehicleMarker(),
      ),
    );

    return markers;
  }

  Widget _buildLoadingState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Loading GPS data...'),
      ],
    ),
  );

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text('Map Error', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(error!, textAlign: TextAlign.center),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingState();
    if (error != null) return _buildErrorState();

    final mapCenter =
        widget.initialCenter ?? userLatLng ?? const LatLng(-2.2180, 113.9220);

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
                onMapEvent: _onMapEvent,
                onTap: widget.onTap,
              ),
          children: [
            if (widget.children.isEmpty)
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gps_app',
                maxZoom: 18,
              ),
            ...widget.children,
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        if (widget.deviceId != null && userLatLng != null && !_isFollowing)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() => _isFollowing = true);
                _resumeFollowingTimer?.cancel();
                _mapController.move(userLatLng!, currentZoom);
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

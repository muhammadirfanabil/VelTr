import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../services/device/deviceService.dart';
import '../../services/maps/map_markers_service.dart';
import '../../widgets/Map/mapWidget.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Common/loading_overlay.dart';
import '../../widgets/Common/confirmation_dialog.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar.dart';
import 'index.dart';

@immutable
class GeofenceMapScreen extends StatefulWidget {
  final String deviceId;

  const GeofenceMapScreen({super.key, required this.deviceId});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

// Previous imports remain the same...

class _GeofenceMapScreenState extends State<GeofenceMapScreen>
    with SingleTickerProviderStateMixin {
  // Simplified state management
  List<LatLng> polygonPoints = [];
  bool showPolygon = false;
  bool isLoading = false;
  bool isSaving = false;
  bool isLoadingDeviceLocation = false;
  LatLng? currentLocation;
  LatLng? deviceLocation;
  String? deviceName;
  // Services
  final GeofenceService _geofenceService = GeofenceService();
  final DeviceService _deviceService = DeviceService();

  // Map controller
  final MapController _mapController = MapController();

  // Timers
  Timer? _autoUpdateTimer;

  // Firebase listeners
  StreamSubscription<DatabaseEvent>? _deviceGpsListener;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Add error handling to prevent crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeInitialize();
    });
  }

  Future<void> _safeInitialize() async {
    try {
      await _getCurrentLocation();
      await _loadDeviceName();
      await _loadDeviceLocation();
      _startAutoUpdateTimer();
    } catch (e) {
      debugPrint('Error during initialization: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _deviceGpsListener?.cancel();
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
          print('Current Location set: $currentLocation'); // Debug print
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showError(
            context,
            'Failed to get location: ${e.toString()}',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadDeviceName() async {
    try {
      final name = await _deviceService.getDeviceNameById(widget.deviceId);
      if (mounted) {
        setState(() {
          deviceName = name ?? 'Device ${widget.deviceId}';
        });
      }
    } catch (e) {
      debugPrint('Error loading device name: $e');
      if (mounted) {
        setState(() {
          deviceName = 'Device ${widget.deviceId}';
        });
      }
    }
  }

  Future<void> _loadDeviceLocation() async {
    try {
      setState(() {
        isLoadingDeviceLocation = true;
      });

      // Get the device name (MAC address) for Firebase Realtime Database
      final deviceName = await _deviceService.getDeviceNameById(
        widget.deviceId,
      );

      if (deviceName != null && mounted) {
        debugPrint('🔧 [DEVICE_GPS] Loading GPS data for device: $deviceName');

        // Set up Firebase listener for device GPS data
        final ref = FirebaseDatabase.instance.ref('devices/$deviceName/gps');

        _deviceGpsListener = ref.onValue.listen(
          (event) {
            debugPrint(
              '📡 [DEVICE_GPS] GPS data event received for $deviceName',
            );

            if (event.snapshot.exists &&
                event.snapshot.value != null &&
                mounted) {
              final data = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );
              debugPrint('📡 [DEVICE_GPS] GPS Data: $data');

              final lat = _parseDouble(data['latitude']);
              final lon = _parseDouble(data['longitude']);

              if (lat != null && lon != null && lat != 0.0 && lon != 0.0) {
                setState(() {
                  deviceLocation = LatLng(lat, lon);
                  isLoadingDeviceLocation = false;
                });
                debugPrint(
                  '✅ [DEVICE_GPS] Device location updated: $lat, $lon',
                );

                // Center map on both locations when device location is available
                _centerMapOnLocations();
              } else {
                debugPrint('⚠️ [DEVICE_GPS] Invalid GPS coordinates received');
              }
            } else {
              debugPrint('❌ [DEVICE_GPS] No GPS data available for device');
              if (mounted) {
                setState(() {
                  isLoadingDeviceLocation = false;
                });
              }
            }
          },
          onError: (error) {
            debugPrint('❌ [DEVICE_GPS] Firebase GPS listener error: $error');
            if (mounted) {
              setState(() {
                isLoadingDeviceLocation = false;
              });
            }
          },
        );
      } else {
        debugPrint('❌ [DEVICE_GPS] Could not get device name for GPS data');
        if (mounted) {
          setState(() {
            isLoadingDeviceLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [DEVICE_GPS] Error setting up device location: $e');
      if (mounted) {
        setState(() {
          isLoadingDeviceLocation = false;
        });
      }
    }
  }

  /// Parse double value safely from dynamic data
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  void _startAutoUpdateTimer() {
    // Update device location every 10 seconds
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && deviceLocation != null) {
        // Optionally center map on device location if it moves significantly
        _checkForLocationUpdate();
      }
    });
  }

  void _checkForLocationUpdate() {
    if (deviceLocation != null && currentLocation != null) {
      // Calculate distance between device and current center
      final distance = _calculateDistance(
        deviceLocation!,
        _mapController.camera.center,
      );

      // If device moved more than 100 meters from view center, optionally recenter
      if (distance > 0.1) {
        debugPrint('🗺️ Device moved significantly, consider recentering');
        // Auto-recenter disabled to not interrupt user interaction
        // _mapController.move(deviceLocation!, _mapController.camera.zoom);
      }
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (showPolygon || isSaving) return;

    setState(() {
      polygonPoints.add(point);
    });

    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }

  void _onContinuePressed() {
    if (polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackbarUtils.showInfo(
          context,
          'At least 3 points are required to create a geofence area.',
        ),
      );
      return;
    }

    setState(() {
      showPolygon = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackbarUtils.showSuccess(
        context,
        'Geofence area created! Review and save.',
      ),
    );
  }

  void _onUndoPressed() {
    if (polygonPoints.isEmpty) return;

    setState(() {
      polygonPoints.removeLast();
      if (polygonPoints.length < 3) {
        showPolygon = false;
      }
    });

    // Provide haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _onSavePressed() {
    HapticFeedback.mediumImpact();
    _showSaveDialog();
  }

  void _onResetPressed() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Reset Points',
      content:
          'Are you sure you want to clear all points? This action cannot be undone.',
      confirmText: 'Reset',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed == true) {
      setState(() {
        polygonPoints.clear();
        showPolygon = false;
      });
      // Provide haptic feedback
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _showSaveDialog() async {
    final theme = Theme.of(context);
    final nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.save, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Save Geofence'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Geofence Name',
                    hintText: 'Enter a descriptive name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Points: ${polygonPoints.length}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context, name);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    ).then((result) {
      if (result != null && result.isNotEmpty) {
        _saveGeofence(result);
      }
    });
  }

  Future<void> _saveGeofence(String name) async {
    setState(() => isSaving = true);

    try {
      final geofencePoints =
          polygonPoints
              .map(
                (p) =>
                    GeofencePoint(latitude: p.latitude, longitude: p.longitude),
              )
              .toList();

      final geofence = Geofence(
        id: '',
        deviceId: widget.deviceId,
        ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
        name: name,
        points: geofencePoints,
        status: true,
        createdAt: DateTime.now(),
      );

      final validationError = _geofenceService.validateGeofence(geofence);
      if (validationError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackbarUtils.showError(context, validationError));
        return;
      }

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Save Geofence',
        content: 'Are you sure you want to save this geofence?',
        confirmText: 'Save',
        confirmColor: Theme.of(context).colorScheme.primary,
      );

      if (confirmed == true) {
        await _geofenceService.createGeofence(geofence);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackbarUtils.showSuccess(
              context,
              'Geofence "$name" saved successfully!',
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GeofenceListScreen(deviceId: widget.deviceId),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showError(
            context,
            'Failed to save geofence: ${e.toString()}',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // Dialog methods
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            content: const ErrorCard(
              message: 'Please enable location services to use this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            content: const ErrorCard(
              message: 'Location permission is required to create geofences.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            content: const ErrorCard(
              message:
                  'Please enable location permission in settings to use this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Centers the map on both user and device locations when available
  void _centerMapOnLocations() {
    if (currentLocation == null) return;

    try {
      if (deviceLocation != null) {
        // If both locations are available, calculate center point
        final centerLat =
            (currentLocation!.latitude + deviceLocation!.latitude) / 2;
        final centerLng =
            (currentLocation!.longitude + deviceLocation!.longitude) / 2;
        _mapController.move(LatLng(centerLat, centerLng), 14.0);
      } else {
        // If only user location is available, center on user
        _mapController.move(currentLocation!, 15.0);
      }
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
  }

  /// Builds the current user location marker (blue dot) using centralized service
  Widget _buildCurrentLocationMarker() {
    if (currentLocation == null) return const SizedBox.shrink();

    return MapMarkersService.createUserLocationMarker(currentLocation!);
  }

  /// Builds the device location marker using centralized service
  Widget _buildDeviceLocationMarker() {
    // Don't show device marker if location is not available
    if (deviceLocation == null) {
      return const SizedBox.shrink();
    }

    return MapMarkersService.createDeviceLocationMarker(
      deviceLocation!,
      isLoading: isLoadingDeviceLocation,
      deviceName: deviceName,
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showPolygon && polygonPoints.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onUndoPressed,
                icon: const Icon(Icons.undo),
                label: const Text('Undo Last Point'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade500,
                  foregroundColor: theme.colorScheme.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showPolygon && polygonPoints.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onResetPressed,
                icon: const Icon(Icons.clear_all),
                label: const Text('Reset All Points'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child:
                showPolygon && polygonPoints.length >= 3
                    ? FilledButton.icon(
                      onPressed: isSaving ? null : _onSavePressed,
                      icon:
                          isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.save),
                      label: Text(isSaving ? 'Saving...' : 'Save Geofence'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                    : FilledButton(
                      onPressed: _onContinuePressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        polygonPoints.length < 3
                            ? 'Add ${3 - polygonPoints.length} more point${3 - polygonPoints.length == 1 ? '' : 's'}'
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Define Geofence Area',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 22,
          ),
        ),
      ),
      body:
          isLoading || currentLocation == null
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: MapWidget(
                      initialCenter: currentLocation,
                      initialZoom: 15.0,
                      onTap: _onMapTap,
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.gps_app',
                          maxZoom: 18,
                        ),
                        if (polygonPoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: polygonPoints,
                                color:
                                    showPolygon
                                        ? AppColors.primaryBlue
                                        : AppColors.primaryBlue.withValues(
                                          alpha: 0.7,
                                        ),
                                strokeWidth: 3.0,
                              ),
                            ],
                          ),
                        if (showPolygon && polygonPoints.length >= 3)
                          PolygonLayer(
                            polygonCulling: false,
                            polygons: [
                              Polygon(
                                points: [...polygonPoints, polygonPoints.first],
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.3,
                                ),
                                borderColor: AppColors.primaryBlue,
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ), // Polygon point markers using centralized service
                        if (polygonPoints.isNotEmpty)
                          MapMarkersService.createPolygonPointMarkers(
                            polygonPoints,
                          ),
                        // User location marker (blue dot)
                        if (currentLocation != null)
                          _buildCurrentLocationMarker(),
                        // Device location marker
                        if (deviceLocation != null)
                          _buildDeviceLocationMarker(),
                      ],
                    ),
                  ),
                  if (!showPolygon)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tap to add points',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Points: ${polygonPoints.length} (min: 3)',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _buildActionButtons(),
                  if (isSaving) LoadingOverlay(message: 'Saving geofence...'),
                ],
              ),
    );
  }
}

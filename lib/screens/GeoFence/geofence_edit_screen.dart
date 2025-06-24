import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../services/device/deviceService.dart';
import '../../services/maps/map_markers_service.dart';
import '../../widgets/Map/mapWidget.dart';
import 'package:flutter/services.dart';

import '../../utils/snackbar.dart';
import '../../widgets/Common/loading_overlay.dart';
import '../../widgets/Common/confirmation_dialog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class GeofenceEditScreen extends StatefulWidget {
  final Geofence geofence;

  const GeofenceEditScreen({super.key, required this.geofence});

  @override
  State<GeofenceEditScreen> createState() => _GeofenceEditScreenState();
}

class _GeofenceEditScreenState extends State<GeofenceEditScreen>
    with SingleTickerProviderStateMixin {
  // Core state
  late List<LatLng> polygonPoints;
  late TextEditingController nameController;
  bool isSaving = false;
  bool hasUnsavedChanges = false;
  bool isLoadingDeviceLocation = false;
  LatLng? currentLocation;
  LatLng? deviceLocation;
  String? deviceName;

  // Map controller
  final MapController _mapController = MapController();

  // Services
  final GeofenceService _geofenceService = GeofenceService();
  final DeviceService _deviceService = DeviceService();

  // Timers
  Timer? _autoUpdateTimer;

  // Firebase listeners
  StreamSubscription<DatabaseEvent>? _deviceGpsListener;

  // Animation
  AnimationController? _animationController;
  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
    // Load location data for device and current location
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
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    nameController.dispose();
    _deviceGpsListener?.cancel();
    _autoUpdateTimer?.cancel();
    super.dispose();
  }

  void _initializeData() {
    polygonPoints =
        widget.geofence.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

    nameController = TextEditingController(text: widget.geofence.name);
    nameController.addListener(_onDataChanged);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _animationController != null) {
        _animationController!.forward();
      }
    });
  }

  void _onDataChanged() {
    if (!hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = true;
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      polygonPoints.add(point);
      hasUnsavedChanges = true;
    });
    _showHapticFeedback();
  }

  void _onUndoPressed() {
    if (polygonPoints.isEmpty) return;

    setState(() {
      polygonPoints.removeLast();
      hasUnsavedChanges = true;
    });
    _showHapticFeedback();
  }

  void _onResetPressed() {
    _showResetConfirmationDialog();
  }

  Future<void> _onSavePressed() async {
    if (nameController.text.trim().isEmpty) {
      SnackbarUtils.showWarning(context, 'Please enter a geofence name');
      return;
    }

    if (polygonPoints.length < 3) {
      SnackbarUtils.showWarning(
        context,
        'At least 3 points are required for a geofence',
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final geofencePoints =
          polygonPoints
              .map(
                (latLng) => GeofencePoint(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                ),
              )
              .toList();

      final updatedGeofence = Geofence(
        id: widget.geofence.id,
        deviceId: widget.geofence.deviceId,
        ownerId: widget.geofence.ownerId,
        name: nameController.text.trim(),
        address: widget.geofence.address,
        points: geofencePoints,
        status: widget.geofence.status,
        createdAt: widget.geofence.createdAt,
        updatedAt: DateTime.now(),
      );

      final validationError = _geofenceService.validateGeofence(
        updatedGeofence,
      );
      if (validationError != null) {
        SnackbarUtils.showError(context, validationError);
        return;
      }

      await _geofenceService.updateGeofence(updatedGeofence);

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Geofence updated successfully!');

        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to update geofence: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _showResetConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Reset Points',
            content:
                'Are you sure you want to clear all points? This action cannot be undone.',
            confirmText: 'Reset',
            cancelText: 'Cancel',
          ),
    );

    if (result == true) {
      setState(() {
        polygonPoints.clear();
        hasUnsavedChanges = true;
      });
      _showHapticFeedback();
    }
  }

  Future<bool> _onWillPop() async {
    if (!hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => const ConfirmationDialog(
            title: 'Unsaved Changes',
            content:
                'You have unsaved changes. Are you sure you want to leave?',
            confirmText: 'Leave',
            cancelText: 'Stay',
          ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: Stack(
        children: [
          // Wrap map in SafeArea and error boundary
          _buildMapWithErrorHandling(),
          _buildInstructionCard(),
          _buildActionButtons(), // Add location buttons on the right side (positioned lower due to instruction card)
          Positioned(right: 16, top: 300, child: _buildLocationButtons()),
          if (isSaving) _buildSavingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMapWithErrorHandling() {
    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          return _buildMap();
        } catch (e) {
          debugPrint('Map rendering error: $e');
          return _buildFallbackMap();
        }
      },
    );
  }

  Widget _buildFallbackMap() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.backgroundSecondary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.map, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Map temporarily unavailable',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again or restart the app',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Force rebuild
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.backgroundPrimary,
      leading: IconButton(
        icon: Icon(AppIcons.back, color: AppColors.primaryBlue, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Edit Geofence',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 22,
        ),
      ),
      actions: [
        if (hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              'Unsaved',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMap() {
    final center =
        polygonPoints.isNotEmpty ? polygonPoints.first : const LatLng(0, 0);

    return MapWidget(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.0,
        onTap: _onMapTap,
        backgroundColor: AppColors.backgroundSecondary,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.gps_app',
          // Add error handling for tile loading
          errorTileCallback: (tile, error, stackTrace) {
            debugPrint('Tile loading error: $error');
          },
          maxZoom: 18,
          maxNativeZoom: 18,
        ),
        // Conditionally render layers to reduce complexity
        if (polygonPoints.length >= 2) _buildPolylineLayer(),
        if (polygonPoints.length >= 3) _buildPolygonLayer(),
        if (polygonPoints.isNotEmpty) _buildMarkerLayer(),
        if (deviceLocation != null) _buildDeviceLocationMarker(),
        if (currentLocation != null) _buildCurrentLocationMarker(),
      ],
    );
  }

  Widget _buildPolylineLayer() {
    if (polygonPoints.length < 2) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: polygonPoints,
          color: AppColors.primaryBlue,
          strokeWidth: 3.0,
        ),
      ],
    );
  }

  Widget _buildPolygonLayer() {
    if (polygonPoints.length < 3) return const SizedBox.shrink();

    return PolygonLayer(
      polygonCulling: false,
      polygons: [
        Polygon(
          points: [...polygonPoints, polygonPoints.first],
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
          borderColor: AppColors.primaryBlue,
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  Widget _buildMarkerLayer() {
    return MapMarkersService.createPolygonPointMarkers(polygonPoints);
  }

  Widget _buildCurrentLocationMarker() {
    if (currentLocation == null) return const SizedBox.shrink();

    return MapMarkersService.createUserLocationMarker(currentLocation!);
  }

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
          // Show points info when available
          if (polygonPoints.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.myLocation, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geofence Points',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.infoText,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${polygonPoints.length} points defined${polygonPoints.length >= 3 ? " (Valid geofence)" : " (Minimum 3 required)"}',
                          style: TextStyle(color: AppColors.info, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: polygonPoints.isEmpty ? null : _onUndoPressed,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.grey.shade500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: polygonPoints.isEmpty ? null : _onResetPressed,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Reset'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed:
                (isSaving || polygonPoints.length < 3) ? null : _onSavePressed,
            icon:
                isSaving
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                    : const Icon(Icons.save),
            label: Text(isSaving ? 'Saving...' : 'Save Changes'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  polygonPoints.length >= 3
                      ? theme.colorScheme.primary
                      : Colors.grey[400],
              foregroundColor:
                  polygonPoints.length >= 3
                      ? theme.colorScheme.onPrimary
                      : Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: "center_map",
          onPressed: () {
            if (polygonPoints.isNotEmpty) {
              // Center on geofence area
              final bounds = _calculateBounds(polygonPoints);
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(50),
                ),
              );
            }
          },
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          child: const Icon(Icons.center_focus_strong, size: 20),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "device_location",
          onPressed:
              deviceLocation != null
                  ? () {
                    _mapController.move(deviceLocation!, 16.0);
                  }
                  : null,
          backgroundColor:
              deviceLocation != null ? Colors.orange[600] : Colors.grey[400],
          foregroundColor: Colors.white,
          child:
              isLoadingDeviceLocation
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Icon(Icons.gps_fixed, size: 20),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: "my_location",
          onPressed:
              currentLocation != null
                  ? () {
                    _mapController.move(currentLocation!, 16.0);
                  }
                  : null,
          backgroundColor:
              currentLocation != null ? Colors.blue[600] : Colors.grey[400],
          foregroundColor: Colors.white,
          child: const Icon(Icons.my_location, size: 20),
        ),
      ],
    );
  }

  // Helper method to calculate bounds for a list of points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  Widget _buildSavingOverlay() {
    return const LoadingOverlay(message: 'Updating geofence...');
  }

  void _showHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Failed to get current location: $e');
    }
  }

  Future<void> _loadDeviceName() async {
    try {
      final name = await _deviceService.getDeviceNameById(
        widget.geofence.deviceId,
      );
      if (mounted) {
        setState(() {
          deviceName = name ?? 'Device ${widget.geofence.deviceId}';
        });
      }
    } catch (e) {
      debugPrint('Error loading device name: $e');
      if (mounted) {
        setState(() {
          deviceName = 'Device ${widget.geofence.deviceId}';
        });
      }
    }
  }

  Future<void> _loadDeviceLocation() async {
    if (mounted) {
      setState(() {
        isLoadingDeviceLocation = true;
      });
    }

    try {
      final deviceName = await _deviceService.getDeviceNameById(
        widget.geofence.deviceId,
      );

      if (deviceName != null) {
        final ref = FirebaseDatabase.instance.ref('devices/$deviceName/gps');

        _deviceGpsListener = ref.onValue.listen(
          (DatabaseEvent event) {
            if (event.snapshot.exists && mounted) {
              final data = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );

              final lat = _parseDouble(data['latitude']);
              final lon = _parseDouble(data['longitude']);

              if (lat != null && lon != null) {
                setState(() {
                  deviceLocation = LatLng(lat, lon);
                  isLoadingDeviceLocation = false;
                });
              } else {
                setState(() {
                  isLoadingDeviceLocation = false;
                });
              }
            }
          },
          onError: (error) {
            debugPrint('Firebase GPS listener error: $error');
            if (mounted) {
              setState(() {
                isLoadingDeviceLocation = false;
              });
            }
          },
        );
      } else {
        if (mounted) {
          setState(() {
            isLoadingDeviceLocation = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error setting up device location: $e');
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
        // Optional: Check for location updates
      }
    });
  }

  Widget _buildInstructionCard() {
    final theme = Theme.of(context);

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instruction header
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap to add points • Points: ${polygonPoints.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Geofence Name Input
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Geofence Name',
                  hintText: 'Enter geofence name',
                  prefixIcon: Icon(
                    Icons.location_on,
                    color: theme.colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Device Location Info
              if (deviceLocation != null) ...[
                Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device location: ${deviceLocation!.latitude.toStringAsFixed(6)}, ${deviceLocation!.longitude.toStringAsFixed(6)}${deviceName != null ? " ($deviceName)" : ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // User Location Info
              if (currentLocation != null) ...[
                Row(
                  children: [
                    Icon(Icons.my_location, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your location: ${currentLocation!.latitude.toStringAsFixed(6)}, ${currentLocation!.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

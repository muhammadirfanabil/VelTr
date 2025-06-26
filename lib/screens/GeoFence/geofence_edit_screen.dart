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
  late List<LatLng> polygonPoints;
  late TextEditingController nameController;
  bool isSaving = false;
  bool hasUnsavedChanges = false;
  bool isLoadingDeviceLocation = false;
  LatLng? currentLocation;
  LatLng? deviceLocation;
  String? deviceName;

  final MapController _mapController = MapController();

  final GeofenceService _geofenceService = GeofenceService();
  final DeviceService _deviceService = DeviceService();

  Timer? _autoUpdateTimer;
  StreamSubscription<DatabaseEvent>? _deviceGpsListener;
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
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
        await Future.delayed(const Duration(milliseconds: 1200));
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
          _buildMapWithErrorHandling(),
          _buildMinimalistInstructionCard(),
          _buildMinimalistActionButtons(),
          Positioned(right: 16, top: 260, child: _buildLocationButtons()),
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.map, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Map unavailable',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try again or restart the app',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
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
        tooltip: 'Back',
      ),
      title: const Text(
        'Edit Geofence',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        if (hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              backgroundColor: AppColors.error.withOpacity(0.06),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              label: Text(
                'Unsaved',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
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
          errorTileCallback: (tile, error, stackTrace) {
            debugPrint('Tile loading error: $error');
          },
          maxZoom: 18,
          maxNativeZoom: 18,
        ),
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
          color: AppColors.primaryBlue.withOpacity(0.17),
          borderColor: AppColors.primaryBlue,
          borderStrokeWidth: 2,
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
    if (deviceLocation == null) return const SizedBox.shrink();

    return MapMarkersService.createDeviceLocationMarker(
      deviceLocation!,
      isLoading: isLoadingDeviceLocation,
      deviceName: deviceName,
    );
  }

  // --- Modern Minimalist Instruction Card ---
  Widget _buildMinimalistInstructionCard() {
    final theme = Theme.of(context);

    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.white.withOpacity(0.93),
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step-by-step, icon-guided instructions
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tap the map to add points',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                      fontSize: 14.5,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          polygonPoints.length >= 3
                              ? Colors.green.withOpacity(0.09)
                              : Colors.red.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          polygonPoints.length >= 3
                              ? Icons.check_circle
                              : Icons.info_outline_rounded,
                          color:
                              polygonPoints.length >= 3
                                  ? Colors.green
                                  : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          polygonPoints.length >= 3
                              ? 'Valid'
                              : 'At least 3 points',
                          style: TextStyle(
                            color:
                                polygonPoints.length >= 3
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Geofence Name
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter geofence name',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.03,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Device and User Location Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.orange, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          deviceLocation != null
                              ? 'Device: ${deviceLocation!.latitude.toStringAsFixed(5)}, ${deviceLocation!.longitude.toStringAsFixed(5)}'
                              : 'Device location unavailable',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_pin, color: Colors.blue, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          currentLocation != null
                              ? 'You: ${currentLocation!.latitude.toStringAsFixed(5)}, ${currentLocation!.longitude.toStringAsFixed(5)}'
                              : 'Your location unavailable',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Minimalist Action Buttons ---
  Widget _buildMinimalistActionButtons() {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Undo/Reset row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: polygonPoints.isNotEmpty ? _onUndoPressed : null,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueGrey.shade800,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: polygonPoints.isNotEmpty ? _onResetPressed : null,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reset'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Save button
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
                    : const Icon(Icons.save_rounded),
            label: Text(isSaving ? 'Saving...' : 'Save Changes'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  polygonPoints.length >= 3
                      ? theme.colorScheme.primary
                      : Colors.grey[300],
              foregroundColor:
                  polygonPoints.length >= 3
                      ? theme.colorScheme.onPrimary
                      : Colors.grey[600],
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.1,
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
        _MinimalFAB(
          icon: Icons.center_focus_strong_rounded,
          tooltip: "Center geofence",
          onPressed:
              polygonPoints.isNotEmpty
                  ? () {
                    final bounds = _calculateBounds(polygonPoints);
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(50),
                      ),
                    );
                  }
                  : null,
          backgroundColor: Colors.white, // Swapped
          iconColor: Colors.blue[700], // Swapped
        ),
        const SizedBox(height: 9),
        _MinimalFAB(
          icon: Icons.gps_fixed_rounded,
          tooltip: "Device location",
          onPressed:
              deviceLocation != null
                  ? () {
                    _mapController.move(deviceLocation!, 16.0);
                  }
                  : null,
          backgroundColor: Colors.white, // Swapped (for orange icon as well)
          iconColor: Colors.orange, // Swapped
          isLoading: isLoadingDeviceLocation,
        ),
        const SizedBox(height: 9),
        _MinimalFAB(
          icon: Icons.person_pin,
          tooltip: "Your location",
          onPressed:
              currentLocation != null
                  ? () {
                    _mapController.move(currentLocation!, 16.0);
                  }
                  : null,
          backgroundColor: Colors.white, // Swapped
          iconColor: Colors.blue[700], // Swapped
        ),
      ],
    );
  }

  // Minimalist floating action button for map controls
  Widget _MinimalFAB({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: tooltip,
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        elevation: 1,
        mini: true,
        child:
            isLoading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Icon(icon, size: 20, color: iconColor ?? Colors.white),
      ),
    );
  }

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
    _autoUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && deviceLocation != null) {
        // Optionally refresh marker
      }
    });
  }
}

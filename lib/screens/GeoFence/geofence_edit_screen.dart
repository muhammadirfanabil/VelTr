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
import '../../widgets/Map/mapWidget.dart';

class GeofenceEditScreen extends StatefulWidget {
  final Geofence geofence;

  const GeofenceEditScreen({super.key, required this.geofence});

  @override
  State<GeofenceEditScreen> createState() => _GeofenceEditScreenState();
}

class _GeofenceEditScreenState extends State<GeofenceEditScreen>
    with SingleTickerProviderStateMixin {  // Core state
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

  // Animation - Initialize with nullable types first
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
    // Convert GeofencePoint objects to LatLng for the map
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

    // Start animation after everything is set up
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

  Future<void> _onSavePressed() async {
    if (nameController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter a geofence name',
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    if (polygonPoints.length < 3) {
      _showSnackBar(
        'At least 3 points are required for a geofence',
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      // Convert LatLng points to GeofencePoint objects
      final geofencePoints =
          polygonPoints
              .map(
                (latLng) => GeofencePoint(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                ),
              )              .toList(); // Create updated Geofence object
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

      // Validate geofence
      final validationError = _geofenceService.validateGeofence(
        updatedGeofence,
      );
      if (validationError != null) {
        _showSnackBar(validationError, Colors.orange, Icons.warning);
        return;
      }

      // Update using service layer
      await _geofenceService.updateGeofence(updatedGeofence);

      if (mounted) {
        _showSnackBar(
          'Geofence updated successfully!',
          Colors.green,
          Icons.check_circle,
        );

        // Delay navigation to show success message
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to update geofence: ${e.toString()}',
          Colors.red,
          Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
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

  Future<void> _showResetConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Reset Points'),
              ],
            ),
            content: const Text(
              'Are you sure you want to clear all points? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset'),
              ),
            ],
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
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Leave'),
              ),
            ],
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
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Stack(
            children: [
              // Wrap map in SafeArea and error boundary
              _buildMapWithErrorHandling(),
              _buildInstructionCard(),
              _buildActionButtons(),
              if (isSaving) _buildSavingOverlay(),
            ],
          ),
        ),
        floatingActionButton: _buildLocationButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Map temporarily unavailable',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again or restart the app',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Geofence Area',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            widget.geofence.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        if (hasUnsavedChanges)
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Unsaved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
        backgroundColor: Colors.grey[100]!,
      ),      children: [
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
          color: Colors.blue[600]!,
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
          color: Colors.blue.withOpacity(0.3),
          borderColor: Colors.blue[600]!,
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  Widget _buildMarkerLayer() {
    return MarkerLayer(
      markers:
          polygonPoints.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final point = entry.value;
            return Marker(
              point: point,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
  Widget _buildCurrentLocationMarker() {
    if (currentLocation == null) return const SizedBox.shrink();
    
    return MarkerLayer(
      markers: [
        Marker(
          point: currentLocation!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceLocationMarker() {
    // Don't show device marker if location is not available
    if (deviceLocation == null) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: [
        Marker(
          point: deviceLocation!,
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring for better visibility
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange[600]!.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange[600]!, width: 2),
                ),
              ),
              // Inner device marker
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.gps_fixed, color: Colors.white, size: 14),
              ),
              // Loading indicator if still loading
              if (isLoadingDeviceLocation)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }  Widget _buildInstructionCard() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Row(
                children: [
                  Icon(Icons.edit_location, color: Colors.blue[600], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Geofence Area',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to add points • Long press markers to delete',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              color: Colors.orange[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                deviceLocation != null
                                    ? 'Orange marker shows device GPS location'
                                    : isLoadingDeviceLocation
                                    ? 'Loading device GPS location...'
                                    : 'Device GPS location unavailable',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.blue[600],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                currentLocation != null
                                    ? 'Blue marker shows your current location'
                                    : 'Getting your location...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Name input field
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
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Points info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Points: ${polygonPoints.length}${hasUnsavedChanges ? " (Modified)" : ""}',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Device info if available
              if (deviceLocation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: Colors.orange[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Location${deviceName != null ? " ($deviceName)" : ""}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${deviceLocation!.latitude.toStringAsFixed(6)}, ${deviceLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildActionButtons() {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Statistics row
              if (polygonPoints.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Geofence Points',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${polygonPoints.length} points defined${polygonPoints.length >= 3 ? " (Valid geofence)" : " (Minimum 3 required)"}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action buttons row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: polygonPoints.isEmpty ? null : _onUndoPressed,
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text('Undo (${polygonPoints.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: polygonPoints.isEmpty ? null : _onResetPressed,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isSaving || polygonPoints.length < 3) ? null : _onSavePressed,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: polygonPoints.length >= 3 ? Colors.green[600] : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          onPressed: deviceLocation != null ? () {
            _mapController.move(deviceLocation!, 16.0);
          } : null,
          backgroundColor: deviceLocation != null ? Colors.orange[600] : Colors.grey[400],
          foregroundColor: Colors.white,
          child: isLoadingDeviceLocation 
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
          onPressed: currentLocation != null ? () {
            _mapController.move(currentLocation!, 16.0);
          } : null,
          backgroundColor: currentLocation != null ? Colors.blue[600] : Colors.grey[400],
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
    }    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Updating geofence...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHapticFeedback() {
    // Add haptic feedback if needed
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
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
      final name = await _deviceService.getDeviceNameById(widget.geofence.deviceId);
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
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gps_app/widgets/Map/mapWidget.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../services/device/deviceService.dart';
import 'index.dart';

class GeofenceMapScreen extends StatefulWidget {
  final String deviceId;

  const GeofenceMapScreen({super.key, required this.deviceId});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen>
    with SingleTickerProviderStateMixin {
  // Core state
  List<LatLng> polygonPoints = [];
  bool showPolygon = false;
  bool isLoading = false;
  bool isSaving = false;
  LatLng? currentLocation; // User's location
  LatLng? deviceLocation; // Device's GPS location
  String? deviceName; // Added for vehicle context
  bool isLoadingDeviceLocation = false; // Services
  final GeofenceService _geofenceService = GeofenceService();
  final DeviceService _deviceService = DeviceService();

  // Firebase listeners
  StreamSubscription<DatabaseEvent>? _deviceGpsListener;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _getCurrentLocation();
    _loadDeviceName();
    _loadDeviceLocation();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _deviceGpsListener?.cancel();
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
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to get location: ${e.toString()}');
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

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (showPolygon || isSaving) return;

    setState(() {
      polygonPoints.add(point);
    });

    _showHapticFeedback();
  }

  void _onContinuePressed() {
    if (polygonPoints.length < 3) {
      _showSnackBar(
        'At least 3 points are required to create a geofence area.',
        Colors.orange,
        Icons.warning,
      );
      return;
    }

    setState(() {
      showPolygon = true;
    });

    _showSnackBar(
      'Geofence area created! Review and save.',
      Colors.green,
      Icons.check_circle,
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
        showPolygon = false;
      });
      _showHapticFeedback();
    }
  }

  Future<void> _onSavePressed() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSaveDialog(),
    );

    if (result != null && result.isNotEmpty) {
      await _saveGeofence(result);
    }
  }

  Widget _buildSaveDialog() {
    final nameController = TextEditingController();

    return StatefulBuilder(
      builder:
          (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.save, color: Colors.blue),
                SizedBox(width: 8),
                Text('Save Geofence'),
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
                          'Points: ${polygonPoints.length}',
                          style: TextStyle(
                            color: Colors.blue[800],
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(context, name);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveGeofence(String name) async {
    setState(() => isSaving = true);

    try {
      // Debug logging for device ID consistency
      debugPrint(
        '🔧 GeofenceMapScreen: Creating geofence with deviceId: ${widget.deviceId}',
      );
      debugPrint(
        '🔧 GeofenceMapScreen: widget.deviceId type: ${widget.deviceId.runtimeType}',
      );

      // Convert LatLng points to GeofencePoint objects
      final geofencePoints =
          polygonPoints
              .map(
                (p) =>
                    GeofencePoint(latitude: p.latitude, longitude: p.longitude),
              )
              .toList(); // Create Geofence model instance
      final geofence = Geofence(
        id: '', // Will be generated by Firestore
        deviceId: widget.deviceId,
        ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
        name: name,
        points: geofencePoints,
        status: true,
        createdAt: DateTime.now(),
      );

      // Validate geofence before saving
      final validationError = _geofenceService.validateGeofence(geofence);
      if (validationError != null) {
        _showError(validationError);
        return;
      } // Save using service layer
      await _geofenceService.createGeofence(geofence);

      debugPrint(
        '✅ GeofenceMapScreen: Geofence "$name" created successfully for device: ${widget.deviceId}',
      );

      if (mounted) {
        _showSnackBar(
          'Geofence "$name" saved successfully!',
          Colors.green,
          Icons.check_circle,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GeofenceListScreen(deviceId: widget.deviceId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save geofence: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || currentLocation == null) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMap(),
          _buildInstructionCard(),
          _buildActionButtons(),
          if (isSaving) _buildSavingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: const Center(
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
            'Define Geofence Area',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          if (deviceName != null)
            Text(
              'For: $deviceName',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: MapWidget(
        options: MapOptions(
          initialCenter: currentLocation!,
          initialZoom: 15.0,
          onTap: _onMapTap,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.gps_app',
          ),
          _buildPolylineLayer(),
          _buildPolygonLayer(),
          _buildMarkerLayer(),
          _buildVehicleMarker(),
          _buildDeviceLocationMarker(),
          _buildCurrentLocationMarker(),
        ],
      ),
    );
  }

  Widget _buildPolylineLayer() {
    if (polygonPoints.length < 2) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: polygonPoints,
          color: showPolygon ? Colors.blue[600]! : Colors.blue[400]!,
          strokeWidth: 3.0,
        ),
      ],
    );
  }

  Widget _buildPolygonLayer() {
    if (!showPolygon || polygonPoints.length < 3) {
      return const SizedBox.shrink();
    }

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
  }

  Widget _buildVehicleMarker() {
    // Calculate the position for the vehicle marker
    LatLng vehiclePosition;
    bool isAtCenter = false;

    if (showPolygon && polygonPoints.length >= 3) {
      // If polygon is complete, show vehicle at the center of the geofence
      vehiclePosition = _calculatePolygonCenter();
      isAtCenter = true;
    } else if (polygonPoints.isNotEmpty) {
      // If drawing, show at the last point to indicate the vehicle's target area
      vehiclePosition = polygonPoints.last;
    } else {
      // If no points yet, show at current location
      vehiclePosition = currentLocation!;
    }

    return MarkerLayer(
      markers: [
        Marker(
          point: vehiclePosition,
          width: isAtCenter ? 60 : 50,
          height: isAtCenter ? 60 : 50,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isAtCenter ? Colors.green[600]! : Colors.blue[600]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: isAtCenter ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.motorcycle,
                  color: isAtCenter ? Colors.green[600]! : Colors.blue[600]!,
                  size: 24,
                ),
                if (isAtCenter)
                  Positioned(
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AREA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Calculate the center point of the polygon
  LatLng _calculatePolygonCenter() {
    if (polygonPoints.isEmpty) return currentLocation!;

    double lat = 0;
    double lng = 0;

    for (final point in polygonPoints) {
      lat += point.latitude;
      lng += point.longitude;
    }

    return LatLng(lat / polygonPoints.length, lng / polygonPoints.length);
  }

  Widget _buildInstructionCard() {
    if (showPolygon) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.blue[600], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Define Vehicle Geofence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add points around your vehicle area',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.motorcycle,
                          color: Colors.blue[600],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            polygonPoints.isNotEmpty
                                ? 'Vehicle icon follows your drawing'
                                : 'Vehicle icon shows current location',
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
                            'Blue marker shows your current location',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Points: ${polygonPoints.length} (min: 3)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showPolygon && polygonPoints.isNotEmpty) ...[
            _buildUndoButton(),
            const SizedBox(height: 12),
          ],
          if (showPolygon && polygonPoints.isNotEmpty) ...[
            _buildResetButton(),
            const SizedBox(height: 12),
          ],
          _buildMainActionButton(),
        ],
      ),
    );
  }

  Widget _buildUndoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onUndoPressed,
        icon: const Icon(Icons.undo),
        label: const Text('Undo Last Point'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onResetPressed,
        icon: const Icon(Icons.clear_all),
        label: const Text('Reset All Points'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    if (showPolygon && polygonPoints.length >= 3) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : _onSavePressed,
          icon:
              isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                  : const Icon(Icons.save),
          label: Text(isSaving ? 'Saving...' : 'Save Geofence'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _onContinuePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          polygonPoints.length < 3
              ? 'Add ${3 - polygonPoints.length} more point${3 - polygonPoints.length == 1 ? '' : 's'}'
              : 'Continue',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
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
                Text('Saving geofence...', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red, Icons.error);
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Service Disabled'),
            content: const Text(
              'Please enable location services to use this feature.',
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
            title: const Text('Location Permission Denied'),
            content: const Text(
              'Location permission is required to create geofences.',
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
            title: const Text('Location Permission Required'),
            content: const Text(
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
}

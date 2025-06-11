import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';

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

  // Services
  final GeofenceService _geofenceService = GeofenceService();

  // Animation - Initialize with nullable types first
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    nameController.dispose();
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
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
        body:
            _fadeAnimation != null
                ? FadeTransition(opacity: _fadeAnimation!, child: _buildBody())
                : _buildBody(), // Fallback without animation
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _buildMap(),
        _buildNameInputCard(),
        _buildInstructionCard(),
        _buildActionButtons(),
        if (isSaving) _buildSavingOverlay(),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      title: const Text(
        'Edit Geofence',
        style: TextStyle(fontWeight: FontWeight.bold),
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

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15.0,
        onTap: _onMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.gps_app',
        ),
        _buildPolylineLayer(),
        _buildPolygonLayer(),
        _buildMarkerLayer(),
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

  Widget _buildNameInputCard() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap to add points • Points: ${polygonPoints.length}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
          if (polygonPoints.isNotEmpty) ...[
            Row(
              children: [
                Expanded(child: _buildUndoButton()),
                const SizedBox(width: 12),
                Expanded(child: _buildResetButton()),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildUndoButton() {
    return ElevatedButton.icon(
      onPressed: polygonPoints.isEmpty ? null : _onUndoPressed,
      icon: const Icon(Icons.undo, size: 18),
      label: const Text('Undo'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 0, 125, 251),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: polygonPoints.isEmpty ? null : _onResetPressed,
      icon: const Icon(Icons.clear_all, size: 18),
      label: const Text('Reset'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSaveButton() {
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
        label: Text(isSaving ? 'Saving...' : 'Save Changes'),
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
}

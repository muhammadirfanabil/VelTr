import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import 'package:flutter/services.dart';

import '../../utils/snackbar.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Common/loading_overlay.dart';
import '../../widgets/Common/confirmation_dialog.dart';

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

  // Animation
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _buildAppBar(),
        body:
            _fadeAnimation != null
                ? FadeTransition(opacity: _fadeAnimation!, child: _buildBody())
                : _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);

    return AppBar(
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
        'Edit Geofence',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
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
                color: theme.colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
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
    final theme = Theme.of(context);

    if (polygonPoints.length < 2) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: polygonPoints,
          color: theme.colorScheme.primary,
          strokeWidth: 3.0,
        ),
      ],
    );
  }

  Widget _buildPolygonLayer() {
    final theme = Theme.of(context);

    if (polygonPoints.length < 3) return const SizedBox.shrink();

    return PolygonLayer(
      polygonCulling: false,
      polygons: [
        Polygon(
          points: [...polygonPoints, polygonPoints.first],
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          borderColor: theme.colorScheme.primary,
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  Widget _buildMarkerLayer() {
    final theme = Theme.of(context);

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
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSecondary,
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
    final theme = Theme.of(context);

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 2,
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
              prefixIcon: Icon(
                Icons.location_on,
                color: theme.colorScheme.primary,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    final theme = Theme.of(context);

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
              Icon(Icons.touch_app, color: theme.colorScheme.primary, size: 20),
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
        ),
      ),
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
          if (polygonPoints.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _onUndoPressed,
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
                    onPressed: _onResetPressed,
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
            onPressed: isSaving ? null : _onSavePressed,
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
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
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

  Widget _buildSavingOverlay() {
    return const LoadingOverlay(message: 'Updating geofence...');
  }

  void _showHapticFeedback() {
    HapticFeedback.mediumImpact();
  }
}

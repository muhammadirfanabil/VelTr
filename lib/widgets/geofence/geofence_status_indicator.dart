import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/Geofence/Geofence.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class GeofenceStatusIndicator extends StatefulWidget {
  final List<Geofence> geofences;
  final LatLng? vehicleLocation;
  final String deviceId;
  final String deviceName;
  final bool isVehicleOnline;

  const GeofenceStatusIndicator({
    Key? key,
    required this.geofences,
    required this.vehicleLocation,
    required this.deviceId,
    required this.deviceName,
    required this.isVehicleOnline,
  }) : super(key: key);

  @override
  State<GeofenceStatusIndicator> createState() =>
      _GeofenceStatusIndicatorState();
}

class _GeofenceStatusIndicatorState extends State<GeofenceStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  List<GeofenceStatus> _currentStatuses = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updateGeofenceStatuses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GeofenceStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.vehicleLocation != widget.vehicleLocation ||
        oldWidget.geofences != widget.geofences) {
      _updateGeofenceStatuses();
    }
  }

  void _updateGeofenceStatuses() {
    if (widget.vehicleLocation == null || widget.geofences.isEmpty) {
      setState(() {
        _currentStatuses = [];
      });
      return;
    }

    final statuses = <GeofenceStatus>[];

    for (final geofence in widget.geofences) {
      if (!geofence.status) continue; // Skip inactive geofences

      final isInside = _isPointInPolygon(
        widget.vehicleLocation!,
        geofence.points,
      );

      statuses.add(
        GeofenceStatus(
          geofence: geofence,
          isInside: isInside,
          lastUpdate: DateTime.now(),
        ),
      );
    }

    setState(() {
      _currentStatuses = statuses;
    });
  }

  bool _isPointInPolygon(LatLng point, List<GeofencePoint> polygon) {
    if (polygon.length < 3) return false;

    final x = point.longitude;
    final y = point.latitude;
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVehicleOnline) {
      return _buildOfflineIndicator();
    }

    if (_currentStatuses.isEmpty) {
      return _buildNoGeofencesIndicator();
    }

    final insideGeofences = _currentStatuses.where((s) => s.isInside).toList();
    final outsideGeofences =
        _currentStatuses.where((s) => !s.isInside).toList();

    return Container(
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              if (insideGeofences.isNotEmpty) ...[
                _buildInsideGeofences(insideGeofences),
                const SizedBox(height: 8),
              ],
              if (outsideGeofences.isNotEmpty) ...[
                _buildOutsideGeofences(outsideGeofences),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final insideCount = _currentStatuses.where((s) => s.isInside).length;
    final totalCount = _currentStatuses.length;

    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: insideCount > 0 ? _pulseAnimation.value : 1.0,              child: Icon(
                insideCount > 0 ? AppIcons.gps : AppIcons.gpsOff,
                color: insideCount > 0 ? AppColors.success : AppColors.textTertiary,
                size: 20,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.deviceName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: insideCount > 0 ? AppColors.success : AppColors.textTertiary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$insideCount/$totalCount',
            style: TextStyle(
              color: AppColors.backgroundPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsideGeofences(List<GeofenceStatus> statuses) {
    return Container(      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.success, color: AppColors.successText, size: 16),
              const SizedBox(width: 4),
              Text(
                'Inside Geofences',
                style: TextStyle(
                  color: AppColors.successText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),          ...statuses.map(
            (status) => _buildGeofenceItem(
              status.geofence.name,
              AppIcons.location,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideGeofences(List<GeofenceStatus> statuses) {
    return Container(      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.locationOff, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                'Outside Geofences',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...statuses.map(
            (status) => _buildGeofenceItem(
              status.geofence.name,
              AppIcons.locationOff,
              AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildGeofenceItem(String name, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: color, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.signal_wifi_off, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.deviceName} - Offline',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoGeofencesIndicator() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.location_disabled, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.deviceName} - No Active Geofences',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Vehicle Marker with Geofence Status
class GeofenceAwareVehicleMarker extends StatefulWidget {
  final LatLng position;
  final List<Geofence> geofences;
  final bool isVehicleOn;
  final VoidCallback? onTap;

  const GeofenceAwareVehicleMarker({
    Key? key,
    required this.position,
    required this.geofences,
    required this.isVehicleOn,
    this.onTap,
  }) : super(key: key);

  @override
  State<GeofenceAwareVehicleMarker> createState() =>
      _GeofenceAwareVehicleMarkerState();
}

class _GeofenceAwareVehicleMarkerState extends State<GeofenceAwareVehicleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isInsideAnyGeofence = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _checkGeofenceStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GeofenceAwareVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.geofences != widget.geofences) {
      _checkGeofenceStatus();
    }
  }

  void _checkGeofenceStatus() {
    bool insideAny = false;

    for (final geofence in widget.geofences) {
      if (!geofence.status) continue;

      if (_isPointInPolygon(widget.position, geofence.points)) {
        insideAny = true;
        break;
      }
    }

    if (insideAny != _isInsideAnyGeofence) {
      setState(() {
        _isInsideAnyGeofence = insideAny;
      });

      if (_isInsideAnyGeofence) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    }
  }

  bool _isPointInPolygon(LatLng point, List<GeofencePoint> polygon) {
    if (polygon.length < 3) return false;

    final x = point.longitude;
    final y = point.latitude;
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring for vehicles inside geofences
          if (_isInsideAnyGeofence)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 60 * _animationController.value,
                  height: 60 * _animationController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                );
              },
            ),

          // Main vehicle icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getVehicleColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.directions_car, color: Colors.white, size: 20),
          ),

          // Status indicator
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getVehicleColor() {
    if (!widget.isVehicleOn) return Colors.grey;
    if (_isInsideAnyGeofence) return Colors.green;
    return Colors.blue;
  }

  Color _getStatusColor() {
    if (!widget.isVehicleOn) return Colors.red;
    if (_isInsideAnyGeofence) return Colors.green;
    return Colors.orange;
  }
}

// Geofence Status Model
class GeofenceStatus {
  final Geofence geofence;
  final bool isInside;
  final DateTime lastUpdate;

  const GeofenceStatus({
    required this.geofence,
    required this.isInside,
    required this.lastUpdate,
  });
}

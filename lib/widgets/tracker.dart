import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../widgets/tracker/info_grid.dart'; // Import the BuildInfoGrid widget
import '../../widgets/tracker/locationdetail_dialog.dart'; // Import the LocationDetailsDialog widget
import '../../widgets/tracker/remote.dart'; // Import the BuildActionButton widget

class VehicleStatusPanel extends StatefulWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? lastUpdated;
  final String? waktuWita;
  final bool isVehicleOn;
  final VoidCallback toggleVehicleStatus;
  final int? satellites;
  final bool isLoading;

  const VehicleStatusPanel({
    super.key,
    this.locationName,
    this.latitude,
    this.longitude,
    this.lastUpdated,
    this.waktuWita,
    required this.isVehicleOn,
    required this.toggleVehicleStatus,
    this.satellites,
    this.isLoading = false,
  });

  @override
  State<VehicleStatusPanel> createState() => _VehicleStatusPanelState();
}

class _VehicleStatusPanelState extends State<VehicleStatusPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get hasValidCoordinates =>
      widget.latitude != null && widget.longitude != null;

  String get coordinatesText =>
      hasValidCoordinates
          ? '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}'
          : 'Coordinates not available';

  String get lastActiveText =>
      (widget.lastUpdated?.isNotEmpty ?? false)
          ? widget.lastUpdated!
          : 'No recent data';

  bool get isOnline {
    if (widget.lastUpdated == null || widget.lastUpdated!.isEmpty) return false;

    try {
      final updatedTime = DateTime.parse(widget.lastUpdated!);
      final now = DateTime.now();
      final difference = now.difference(updatedTime).inMinutes;
      return difference <= 2; // Allow 2 minutes for online status
    } catch (_) {
      return false;
    }
  }

  void _copyLocation() {
    if (hasValidCoordinates) {
      Clipboard.setData(ClipboardData(text: coordinatesText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coordinates copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showLocationDetails() {
    showDialog(
      context: context,
      builder:
          (context) => LocationDetailsDialog(
            locationName: widget.locationName,
            latitude: widget.latitude,
            longitude: widget.longitude,
            lastUpdated: lastActiveText,
            satellites: widget.satellites,
            connectionQuality: isOnline ? 'Good' : 'Poor',
            connectionQualityColor: isOnline ? Colors.green : Colors.red,
            onCopyCoordinates: _copyLocation,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: _showLocationDetails,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.place,
                                        size: 20,
                                        color: Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.locationName ??
                                              'Loading location...',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(theme),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BuildInfoGrid(
                        theme: theme,
                        lastUpdate: lastActiveText,
                        connectionQuality: isOnline ? 100 : 50,
                        connectionQualityColor:
                            isOnline
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                        hasValidCoordinates: hasValidCoordinates,
                        coordinatesText: coordinatesText,
                        onCopyLocation: _copyLocation,
                      ),
                      const SizedBox(height: 20),
                      BuildActionButton(
                        isVehicleOn: widget.isVehicleOn,
                        isDisabled: widget.isLoading,
                        onPressed: widget.toggleVehicleStatus,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: isOnline ? Colors.green.shade200 : Colors.red.shade200,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.shade500 : Colors.red.shade500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VehicleStatusPanel extends StatefulWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? lastUpdated;
  final String? waktuWita;
  final bool isVehicleOn;
  final VoidCallback toggleVehicleStatus;
  final int? satellites;

  const VehicleStatusPanel({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    required this.waktuWita,
    required this.isVehicleOn,
    required this.toggleVehicleStatus,
    required this.satellites,
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
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 8),
                const Text('Location Details'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.locationName != null) ...[
                  _DetailRow(
                    icon: Icons.place,
                    label: 'Address',
                    value: widget.locationName!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (hasValidCoordinates) ...[
                  _DetailRow(
                    icon: Icons.my_location,
                    label: 'Latitude',
                    value: widget.latitude!.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.my_location,
                    label: 'Longitude',
                    value: widget.longitude!.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 12),
                ],
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Last Update',
                  value: lastActiveText,
                ),
                if (widget.satellites != null && widget.satellites! > 0) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.satellite_alt,
                    label: 'Satellites',
                    value: '${widget.satellites} connected',
                  ),
                ],
              ],
            ),
            actions: [
              if (hasValidCoordinates)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _copyLocation();
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
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
                      // Header with status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Location name with tap to see details
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
                          // Online/Offline status badge
                          _buildStatusBadge(theme),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Information grid
                      _buildInfoGrid(theme),

                      const SizedBox(height: 20),

                      // Action button (Turn On/Off only)
                      _buildActionButton(theme),
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

  Widget _buildInfoGrid(ThemeData theme) {
    return Column(
      children: [
        // Coordinates row (tappable to copy)
        if (hasValidCoordinates)
          GestureDetector(
            onTap: _copyLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      coordinatesText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.copy, size: 14, color: Colors.grey.shade500),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_disabled,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Text(
                  'GPS coordinates not available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Last update and satellites info
        Row(
          children: [
            // Last update time
            Expanded(
              child: _buildInfoItem(
                icon: Icons.access_time,
                label: 'Last Update',
                value: _formatLastUpdate(),
                theme: theme,
              ),
            ),

            if (widget.satellites != null && widget.satellites! > 0) ...[
              const SizedBox(width: 16),
              _buildInfoItem(
                icon: Icons.satellite_alt,
                label: 'Satellites',
                value: '${widget.satellites}',
                theme: theme,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLastUpdate() {
    if (widget.lastUpdated == null || widget.lastUpdated!.isEmpty) {
      return 'No data';
    }

    try {
      final updatedTime = DateTime.parse(widget.lastUpdated!);
      final now = DateTime.now();
      final difference = now.difference(updatedTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (_) {
      return widget.lastUpdated ?? 'Unknown';
    }
  }

  Widget _buildActionButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.toggleVehicleStatus,
        icon: Icon(
          widget.isVehicleOn
              ? Icons.power_settings_new
              : Icons.power_settings_new_outlined,
          size: 20,
        ),
        label: Text(
          widget.isVehicleOn ? 'Turn Off Device' : 'Turn On Device',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
              widget.isVehicleOn ? Colors.red.shade600 : Colors.green.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

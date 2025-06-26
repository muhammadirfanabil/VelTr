import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

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
  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
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

  // --- Logic Getters ---

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
      return now.difference(updatedTime).inMinutes <= 2;
    } catch (_) {
      return false;
    }
  }

  // --- UI Actions ---

  void _copyLocation() {
    if (hasValidCoordinates) {
      Clipboard.setData(ClipboardData(text: coordinatesText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Coordinates copied to clipboard'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
                Icon(Icons.location_on, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
                const Text('Location Details'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.locationName != null &&
                    widget.locationName!.isNotEmpty) ...[
                  _DetailRow(
                    icon: Icons.place,
                    label: 'Address',
                    value: widget.locationName!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasValidCoordinates) ...[
                  _DetailRow(
                    icon: Icons.my_location,
                    label: 'Latitude',
                    value: widget.latitude!.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.my_location,
                    label: 'Longitude',
                    value: widget.longitude!.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 10),
                ],
                _DetailRow(
                  icon: Icons.access_time,
                  label: 'Last Update',
                  value: lastActiveText,
                ),
                if (widget.satellites != null && widget.satellites! > 0) ...[
                  const SizedBox(height: 6),
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.13),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // -- Header --
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _showLocationDetails,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 19,
                                    color: AppColors.primaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.locationName?.isNotEmpty == true
                                          ? widget.locationName!
                                          : 'Loading location...',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                            fontSize: 16,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.info_outline,
                                    size: 15,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(theme),
                        ],
                      ),

                      const SizedBox(height: 14),
                      _buildInfoGrid(theme),
                      const SizedBox(height: 16),
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
    final online = isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color:
            online
                ? AppColors.success.withOpacity(0.11)
                : AppColors.error.withOpacity(0.09),
        border: Border.all(
          color:
              online
                  ? AppColors.success.withOpacity(0.30)
                  : AppColors.error.withOpacity(0.23),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: online ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: online ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 12.3,
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
        GestureDetector(
          onTap: hasValidCoordinates ? _copyLocation : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  hasValidCoordinates
                      ? Icons.my_location
                      : Icons.location_disabled,
                  size: 15,
                  color:
                      hasValidCoordinates
                          ? AppColors.primaryBlue
                          : AppColors.textTertiary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    hasValidCoordinates
                        ? coordinatesText
                        : 'GPS coordinates not available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          hasValidCoordinates
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                      fontFamily: hasValidCoordinates ? 'monospace' : null,
                      fontSize: 13.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasValidCoordinates)
                  Icon(Icons.copy, size: 13, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Last update & satellites
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                icon: Icons.access_time_rounded,
                label: 'Last Update',
                value: _formatLastUpdate(),
                theme: theme,
              ),
            ),
            if (widget.satellites != null && widget.satellites! > 0) ...[
              const SizedBox(width: 16),
              _buildInfoItem(
                icon: Icons.satellite_alt_rounded,
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
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11.2,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
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
    final isOn = widget.isVehicleOn;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.toggleVehicleStatus,
        icon: Icon(
          isOn ? Icons.power_settings_new : Icons.power_settings_new_outlined,
          size: 20,
        ),
        label: Text(
          isOn ? 'Turn Off Device' : 'Turn On Device',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isOn ? AppColors.error : AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

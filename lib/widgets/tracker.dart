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
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _pulseController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;

  bool _isActionInProgress = false;
  bool _wasOnlinePreviously = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
    _wasOnlinePreviously = isOnline;
    _updatePulseAnimation();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _updatePulseAnimation() {
    if (isOnline) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void didUpdateWidget(VehicleStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update pulse animation based on online status change
    final wasOnline = _wasOnlinePreviously;
    final isCurrentlyOnline = isOnline;

    if (wasOnline != isCurrentlyOnline) {
      _wasOnlinePreviously = isCurrentlyOnline;
      _updatePulseAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Logic Getters ---

  bool get hasValidCoordinates {
    return widget.latitude != null &&
        widget.longitude != null &&
        widget.latitude!.abs() <= 90 &&
        widget.longitude!.abs() <= 180 &&
        widget.latitude != 0.0 &&
        widget.longitude != 0.0;
  }

  String get coordinatesText {
    if (!hasValidCoordinates) return 'Coordinates not available';
    return '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}';
  }

  String get lastActiveText {
    if (widget.lastUpdated?.isNotEmpty == true) {
      return widget.lastUpdated!;
    }
    return 'No recent data';
  }

  bool get isOnline {
    if (widget.lastUpdated?.isEmpty ?? true || widget.lastUpdated == "-") {
      return false; // Return false if the value is empty or "-".
    }

    try {
      final updatedTime = DateTime.parse(widget.lastUpdated!);
      final now = DateTime.now();
      final differenceInMinutes = now.difference(updatedTime).inMinutes;
      return differenceInMinutes <= 2;
    } catch (e) {
      debugPrint('Error parsing last updated time: $e');
      debugPrint('Raw value was: "${widget.lastUpdated}"');
      return false; // Return false in case of any parsing errors
    }
  }

  String get connectionQuality {
    if (!isOnline) return 'Poor';

    final satellites = widget.satellites ?? 0;
    if (satellites >= 8) return 'Excellent';
    if (satellites >= 6) return 'Good';
    if (satellites >= 4) return 'Fair';
    return 'Poor';
  }

  Color get connectionQualityColor {
    switch (connectionQuality) {
      case 'Excellent':
        return AppColors.success;
      case 'Good':
        return AppColors.success.withOpacity(0.8);
      case 'Fair':
        return Colors.orange;
      case 'Poor':
      default:
        return AppColors.error;
    }
  }

  // --- UI Actions ---

  Future<void> _copyLocation() async {
    if (!hasValidCoordinates) {
      _showSnackBar('No valid coordinates to copy', isError: true);
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: coordinatesText));
      _showSnackBar('Coordinates copied to clipboard');
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to copy coordinates: $e');
      _showSnackBar('Failed to copy coordinates', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  Future<void> _handleVehicleToggle() async {
    if (_isActionInProgress || widget.isLoading) return;

    setState(() {
      _isActionInProgress = true;
    });

    try {
      HapticFeedback.heavyImpact();
      widget.toggleVehicleStatus();

      // Simulate processing time for better UX
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Error toggling vehicle status: $e');
      _showSnackBar('Failed to toggle vehicle status', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  void _showLocationDetails() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _LocationDetailsDialog(
            locationName: widget.locationName,
            latitude: widget.latitude,
            longitude: widget.longitude,
            lastUpdated: lastActiveText,
            satellites: widget.satellites,
            connectionQuality: connectionQuality,
            connectionQualityColor: connectionQualityColor,
            onCopyCoordinates: hasValidCoordinates ? _copyLocation : null,
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
            child: _buildPanel(theme),
          ),
        );
      },
    );
  }

  Widget _buildPanel(ThemeData theme) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 14),
              _buildInfoGrid(theme),
              const SizedBox(height: 16),
              _buildActionButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showLocationDetails,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLocationDisplayText(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap for details',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildStatusBadge(theme),
      ],
    );
  }

  String _getLocationDisplayText() {
    if (widget.isLoading) return 'Loading location...';
    if (widget.locationName?.isNotEmpty == true) return widget.locationName!;
    return 'Location unavailable';
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final online = isOnline;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: online ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color:
                  online
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.error.withOpacity(0.10),
              border: Border.all(
                color:
                    online
                        ? AppColors.success.withOpacity(0.35)
                        : AppColors.error.withOpacity(0.25),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
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
                    boxShadow:
                        online
                            ? [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  online ? 'Online' : 'Offline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: online ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoGrid(ThemeData theme) {
    return Column(
      children: [
        _buildCoordinatesCard(theme),
        const SizedBox(height: 12),
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
            if ((widget.satellites ?? 0) > 0) ...[
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.satellite_alt_rounded,
                  label: 'Signal',
                  value: connectionQuality,
                  theme: theme,
                  valueColor: connectionQualityColor,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCoordinatesCard(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasValidCoordinates ? _copyLocation : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  hasValidCoordinates
                      ? AppColors.primaryBlue.withOpacity(0.15)
                      : AppColors.border.withOpacity(0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasValidCoordinates
                    ? Icons.my_location_rounded
                    : Icons.location_disabled_rounded,
                size: 16,
                color:
                    hasValidCoordinates
                        ? AppColors.primaryBlue
                        : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasValidCoordinates ? 'GPS Coordinates' : 'GPS Signal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValidCoordinates ? coordinatesText : 'Not available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            hasValidCoordinates
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                        fontFamily: hasValidCoordinates ? 'monospace' : null,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasValidCoordinates) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLastUpdate() {
    if (widget.lastUpdated?.isEmpty ?? true) {
      return 'No data';
    }

    try {
      final updatedTime = DateTime.parse(widget.lastUpdated!);
      final now = DateTime.now();
      final difference = now.difference(updatedTime);

      if (difference.inSeconds < 30) {
        return 'Just now';
      } else if (difference.inMinutes < 1) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      debugPrint('Error formatting last update: $e');
      return 'Invalid time';
    }
  }

  Widget _buildActionButton(ThemeData theme) {
    final isOn = widget.isVehicleOn;
    final isDisabled = _isActionInProgress || widget.isLoading;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isDisabled ? null : _handleVehicleToggle,
        icon:
            _isActionInProgress
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8),
                    ),
                  ),
                )
                : Icon(
                  isOn
                      ? Icons.power_settings_new_rounded
                      : Icons.power_settings_new_outlined,
                  size: 20,
                ),
        label: Text(
          _getButtonText(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _getButtonColor(isOn, isDisabled),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDisabled ? 0 : 2,
          shadowColor:
              isOn
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.error.withOpacity(0.3),
        ),
      ),
    );
  }

  String _getButtonText() {
    if (_isActionInProgress) return 'Processing...';
    return widget.isVehicleOn ? 'Turn Off Device' : 'Turn On Device';
  }

  Color _getButtonColor(bool isOn, bool isDisabled) {
    if (isDisabled) return AppColors.textTertiary.withOpacity(0.3);
    return isOn ? AppColors.success : AppColors.error;
  }
}

class _LocationDetailsDialog extends StatelessWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String lastUpdated;
  final int? satellites;
  final String connectionQuality;
  final Color connectionQualityColor;
  final VoidCallback? onCopyCoordinates;

  const _LocationDetailsDialog({
    this.locationName,
    this.latitude,
    this.longitude,
    required this.lastUpdated,
    this.satellites,
    required this.connectionQuality,
    required this.connectionQualityColor,
    this.onCopyCoordinates,
  });

  bool get hasValidCoordinates {
    return latitude != null &&
        longitude != null &&
        latitude!.abs() <= 90 &&
        longitude!.abs() <= 180 &&
        latitude != 0.0 &&
        longitude != 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: AppColors.primaryBlue,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text('Location Details'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locationName?.isNotEmpty == true) ...[
              _DetailRow(
                icon: Icons.place_rounded,
                label: 'Address',
                value: locationName!,
              ),
              const SizedBox(height: 12),
            ],
            if (hasValidCoordinates) ...[
              _DetailRow(
                icon: Icons.my_location_rounded,
                label: 'Latitude',
                value: latitude!.toStringAsFixed(6),
                isCoordinate: true,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.my_location_rounded,
                label: 'Longitude',
                value: longitude!.toStringAsFixed(6),
                isCoordinate: true,
              ),
              const SizedBox(height: 12),
            ],
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Last Update',
              value: lastUpdated,
            ),
            if ((satellites ?? 0) > 0) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.satellite_alt_rounded,
                label: 'Satellites',
                value: '$satellites connected',
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.signal_cellular_alt_rounded,
                label: 'Signal Quality',
                value: connectionQuality,
                valueColor: connectionQualityColor,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (hasValidCoordinates && onCopyCoordinates != null)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onCopyCoordinates!();
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Copy Coordinates'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCoordinate;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isCoordinate = false,
    this.valueColor,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    fontFamily: isCoordinate ? 'monospace' : null,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Add this import
import 'package:firebase_database/firebase_database.dart'; // Add Firebase import
import 'dart:async'; // Add for StreamSubscription
import '../../theme/app_colors.dart';

import '../widgets/tracker/info_grid.dart';
import '../widgets/tracker/locationdetail_dialog.dart';
import '../widgets/tracker/remote.dart';

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
  final String deviceId; // Add deviceId parameter

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
    required this.deviceId, // Add required deviceId
  });

  @override
  State<VehicleStatusPanel> createState() => _VehicleStatusPanelState();
}

class _VehicleStatusPanelState extends State<VehicleStatusPanel>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isActionInProgress = false;
  bool _wasOnlinePreviously = false;

  // Add Firebase real-time listening properties
  StreamSubscription<DatabaseEvent>? _relaySubscription;
  bool _isOnlineFromFirebase = false;
  bool _firebaseDataReceived = false;

  // Separate relay status for the button
  bool _relayStatusFromFirebase = false;
  bool _relayDataReceived = false;

  // Add DateFormat instance for parsing
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
    _wasOnlinePreviously = isOnline;

    // Setup Firebase real-time listener for relay status
    _setupFirebaseListener();
  }

  void _setupFirebaseListener() {
    // Validate device ID before setting up listener
    if (widget.deviceId.isEmpty) {
      debugPrint('Warning: Device ID is empty, cannot setup Firebase listener');
      setState(() {
        _isOnlineFromFirebase = false;
        _firebaseDataReceived = true;
        _relayStatusFromFirebase = false;
        _relayDataReceived = true;
      });
      return;
    }

    try {
      final relayRef = FirebaseDatabase.instance.ref(
        'devices/${widget.deviceId}/relay',
      );

      debugPrint('Setting up Firebase listener for device: ${widget.deviceId}');

      _relaySubscription = relayRef.onValue.listen(
        (DatabaseEvent event) {
          if (mounted && event.snapshot.exists) {
            final relayValue = event.snapshot.value;
            final newOnlineStatus = relayValue == true;
            final newRelayStatus = relayValue == true;

            setState(() {
              _isOnlineFromFirebase = newOnlineStatus;
              _firebaseDataReceived = true;
              _relayStatusFromFirebase = newRelayStatus;
              _relayDataReceived = true;

              // Update previous status for tracking changes
              if (_wasOnlinePreviously != newOnlineStatus) {
                _wasOnlinePreviously = newOnlineStatus;
              }
            });

            debugPrint(
              'Firebase relay status updated: $relayValue (Online: $newOnlineStatus, Relay: $newRelayStatus)',
            );
          } else if (mounted) {
            setState(() {
              _isOnlineFromFirebase = false;
              _firebaseDataReceived = true;
              _relayStatusFromFirebase = false;
              _relayDataReceived = true;
            });
            debugPrint(
              'Firebase relay data not found or null for device: ${widget.deviceId}',
            );
          }
        },
        onError: (error) {
          debugPrint(
            'Firebase relay listener error for device ${widget.deviceId}: $error',
          );
          if (mounted) {
            setState(() {
              _isOnlineFromFirebase = false;
              _firebaseDataReceived = true;
              _relayStatusFromFirebase = false;
              _relayDataReceived = true;
            });
          }
        },
      );
    } catch (e) {
      debugPrint(
        'Error setting up Firebase listener for device ${widget.deviceId}: $e',
      );
      if (mounted) {
        setState(() {
          _isOnlineFromFirebase = false;
          _firebaseDataReceived = true;
          _relayStatusFromFirebase = false;
          _relayDataReceived = true;
        });
      }
    }
  }

  void _setupAnimations() {
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
  }

  @override
  void didUpdateWidget(VehicleStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasOnline = _wasOnlinePreviously;
    final isCurrentlyOnline = isOnline;

    if (wasOnline != isCurrentlyOnline) {
      _wasOnlinePreviously = isCurrentlyOnline;
    }
  }

  @override
  void dispose() {
    // Clean up the Firebase listener
    _relaySubscription?.cancel();
    _animationController.dispose();
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
    // Use Firebase relay data if available, otherwise fall back to timestamp logic
    if (_firebaseDataReceived) {
      return _isOnlineFromFirebase;
    }

    // Fallback to timestamp-based logic
    if (widget.lastUpdated == null ||
        widget.lastUpdated!.isEmpty ||
        widget.lastUpdated == '-') {
      return false;
    }

    try {
      final updatedTime = _dateFormat.parse(widget.lastUpdated!);
      final now = DateTime.now();
      final differenceInMinutes = now.difference(updatedTime).inMinutes;

      return differenceInMinutes <= 2;
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      debugPrint('Timestamp value: ${widget.lastUpdated}');
      return false;
    }
  }

  String get connectionQuality {
    if (!isOnline) return 'No Signal';

    final satellites = widget.satellites ?? 0;
    if (satellites >= 8) return 'Excellent';
    if (satellites >= 6) return 'Good';
    if (satellites >= 4) return 'Fair';
    if (satellites >= 2) return 'Poor';
    return 'No Signal';
  }

  Color get connectionQualityColor {
    switch (connectionQuality) {
      case 'Excellent':
        return Colors.teal.shade800;
      case 'Good':
        return AppColors.success.withValues(alpha: 0.8);
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return AppColors.error;
      case 'No Signal':
      default:
        return Colors.black;
    }
  }

  /// Get the actual vehicle/relay status from Firebase
  /// Falls back to widget value if Firebase data is not available
  bool _getActualVehicleStatus() {
    // Use Firebase relay data if available, otherwise fall back to widget data
    if (_relayDataReceived) {
      return _relayStatusFromFirebase;
    }

    // Fallback to widget value if Firebase data not yet received
    return widget.isVehicleOn;
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

      // Store the expected new state
      final expectedNewState = !_getActualVehicleStatus();
      debugPrint('Toggle initiated - Expected new state: $expectedNewState');

      // Call the parent toggle function
      widget.toggleVehicleStatus();

      // Wait for Firebase to update (with timeout)
      int attempts = 0;
      const maxAttempts = 10; // 5 seconds max wait
      while (attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (_relayDataReceived &&
            _relayStatusFromFirebase == expectedNewState) {
          debugPrint(
            'Firebase confirmed toggle - New state: $_relayStatusFromFirebase',
          );
          break;
        }

        attempts++;
        debugPrint(
          'Waiting for Firebase confirmation... Attempt $attempts/$maxAttempts',
        );
      }

      if (attempts >= maxAttempts) {
        debugPrint('Toggle timeout - Firebase may not have updated');
        _showSnackBar('Device toggle may not have completed', isError: true);
      } else {
        _showSnackBar(
          expectedNewState ? 'Device turned on' : 'Device turned off',
          isError: false,
        );
      }
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
          (context) => LocationDetailsDialog(
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
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              BuildInfoGrid(
                theme: theme,
                lastUpdate: lastActiveText,
                connectionQuality:
                    connectionQuality, // This is now fixed with a dynamic value
                connectionQualityColor:
                    connectionQualityColor, // so is this one
                hasValidCoordinates:
                    widget.latitude != null && widget.longitude != null,
                coordinatesText: coordinatesText,
                onCopyLocation: _copyLocation,
              ),

              const SizedBox(height: 16),
              BuildActionButton(
                isVehicleOn: _getActualVehicleStatus(),
                isDisabled: _isActionInProgress || widget.isLoading,
                onPressed: _handleVehicleToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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

    // Debug: Print current status source
    debugPrint(
      'Status Badge - Firebase received: $_firebaseDataReceived, '
      'Firebase status: $_isOnlineFromFirebase, '
      'Final online status: $online',
    );
    debugPrint(
      'Action Button - Relay received: $_relayDataReceived, '
      'Relay status: $_relayStatusFromFirebase, '
      'Final vehicle status: ${_getActualVehicleStatus()}',
    );

    return Container(
      width: 72, // Fixed width to ensure consistent size
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color:
            online
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.error.withValues(alpha: 0.10),
        border: Border.all(
          color:
              online
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.error.withValues(alpha: 0.25),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Center the content
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
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            // Use Flexible to prevent overflow
            child: Text(
              online ? 'Online' : 'Offline',
              style: theme.textTheme.bodySmall?.copyWith(
                color: online ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center, // Center align the text
              overflow: TextOverflow.ellipsis, // Handle potential overflow
            ),
          ),
        ],
      ),
    );
  }
}

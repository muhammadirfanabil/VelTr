import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class EnhancedVehicleStatusButton extends StatefulWidget {
  final bool isVehicleOn;
  final bool isDisabled;
  final VoidCallback onPressed;
  final String? lastUpdate;
  final bool hasGpsSignal;

  const EnhancedVehicleStatusButton({
    super.key,
    required this.isVehicleOn,
    required this.isDisabled,
    required this.onPressed,
    this.lastUpdate,
    this.hasGpsSignal = true,
  });

  @override
  State<EnhancedVehicleStatusButton> createState() =>
      _EnhancedVehicleStatusButtonState();
}

class _EnhancedVehicleStatusButtonState
    extends State<EnhancedVehicleStatusButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _statusChangeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for the pulse effect when vehicle is on
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation for status change
    _statusChangeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _statusChangeController, curve: Curves.easeInOut),
    );

    // Start pulse animation if vehicle is on
    if (widget.isVehicleOn && !widget.isDisabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EnhancedVehicleStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle animation state changes
    if (widget.isVehicleOn != oldWidget.isVehicleOn) {
      if (widget.isVehicleOn && !widget.isDisabled) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }

    if (widget.isDisabled != oldWidget.isDisabled) {
      if (widget.isDisabled) {
        _pulseController.stop();
      } else if (widget.isVehicleOn) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusChangeController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      _statusChangeController.forward();
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _statusChangeController.reverse();
  }

  void _handleTapCancel() {
    _statusChangeController.reverse();
  }

  Color get _buttonColor {
    if (widget.isDisabled) {
      return AppColors.textTertiary.withValues(alpha: 0.3);
    }
    // Green when showing "Turn On Device" (vehicle is OFF)
    // Red when showing "Turn Off Device" (vehicle is ON)
    // return widget.isVehicleOn ? AppColors.error : AppColors.success;
    return widget.isVehicleOn ? AppColors.success : AppColors.error;
  }

  Color get _statusIndicatorColor {
    if (widget.isDisabled) {
      return AppColors.textTertiary.withValues(alpha: 0.5);
    }
    if (!widget.hasGpsSignal) {
      return AppColors.warning;
    }
    // Status indicator shows actual vehicle state (not button action)
    return widget.isVehicleOn ? AppColors.success : AppColors.errorDark;
  }

  IconData get _statusIcon {
    if (widget.isDisabled) {
      return Icons.sync;
    }
    return widget.isVehicleOn ? Icons.power_outlined : Icons.power_off_outlined;
  }

  String get _statusText {
    if (widget.isDisabled) {
      return 'Processing...';
    }
    return widget.isVehicleOn ? 'Turn Off Device' : 'Turn On Device';
  }

  String get _statusLabel {
    if (widget.isDisabled) {
      return 'Updating Status';
    }
    if (!widget.hasGpsSignal) {
      return 'No GPS Signal';
    }
    return widget.isVehicleOn ? 'Online' : 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!widget.isDisabled && widget.isVehicleOn)
                  BoxShadow(
                    color: _buttonColor.withValues(alpha: 0.3),
                    blurRadius: 8 * _pulseAnimation.value,
                    spreadRadius: 2 * _pulseAnimation.value,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  onTap: widget.isDisabled ? null : widget.onPressed,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _buttonColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // Status indicator row
                        Row(
                          children: [
                            // Status dot with animation
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _statusIndicatorColor,
                                boxShadow: [
                                  if (widget.isVehicleOn && !widget.isDisabled)
                                    BoxShadow(
                                      color: _statusIndicatorColor.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Status label
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const Spacer(),

                            // Last update time
                            if (widget.lastUpdate != null && !widget.isDisabled)
                              Text(
                                widget.lastUpdate!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Main action button content
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon with loading animation
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child:
                                  widget.isDisabled
                                      ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                              ),
                                        ),
                                      )
                                      : Transform.scale(
                                        scale:
                                            widget.isVehicleOn &&
                                                    !widget.isDisabled
                                                ? _pulseAnimation.value
                                                : 1.0,
                                        child: Icon(
                                          _statusIcon,
                                          size: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),

                            const SizedBox(width: 12),

                            // Action text
                            Text(
                              _statusText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        // GPS signal indicator (if no signal)
                        if (!widget.hasGpsSignal && !widget.isDisabled) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_off,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'GPS Signal Required',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
              ),
            ),
          ),
        );
      },
    );
  }
}

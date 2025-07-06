import 'package:flutter/material.dart';

/// Reusable enhanced update button with visual feedback for pending changes
class EnhancedUpdateButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final Color baseColor;
  final bool hasPendingChanges;
  final IconData? pendingIcon;
  final String? pendingTooltip;

  const EnhancedUpdateButton({
    Key? key,
    required this.onPressed,
    required this.text,
    required this.baseColor,
    this.hasPendingChanges = false,
    this.pendingIcon = Icons.save_rounded,
    this.pendingTooltip,
  }) : super(key: key);

  @override
  State<EnhancedUpdateButton> createState() => _EnhancedUpdateButtonState();
}

class _EnhancedUpdateButtonState extends State<EnhancedUpdateButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.hasPendingChanges) {
      _startPulseAnimation();
    }
  }

  @override
  void didUpdateWidget(EnhancedUpdateButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasPendingChanges != oldWidget.hasPendingChanges) {
      if (widget.hasPendingChanges) {
        _startPulseAnimation();
      } else {
        _pulseController.stop();
      }
    }
  }

  void _startPulseAnimation() {
    _pulseController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.hasPendingChanges ? Colors.orange : widget.baseColor;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Pulsing effect for pending changes
              if (widget.hasPendingChanges)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(
                          alpha: 0.3 * (1 - _pulseAnimation.value),
                        ),
                        blurRadius: 15 * _pulseAnimation.value,
                        spreadRadius: 3 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 0,
                    height: 0,
                  ), // Invisible placeholder
                ),
              // Main button with enhanced styling when changes are pending
              Container(
                decoration:
                    widget.hasPendingChanges
                        ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        )
                        : null,
                child: ElevatedButton(
                  onPressed: widget.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    elevation: widget.hasPendingChanges ? 8 : 2,
                    shadowColor:
                        widget.hasPendingChanges
                            ? Colors.orange.withValues(alpha: 0.5)
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.hasPendingChanges &&
                          widget.pendingIcon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.pendingIcon!,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          fontWeight:
                              widget.hasPendingChanges
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                          fontSize: widget.hasPendingChanges ? 16 : 14,
                          letterSpacing: widget.hasPendingChanges ? 0.5 : 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Badge indicator for pending changes
              if (widget.hasPendingChanges)
                Positioned(
                  top: -6,
                  right: -6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

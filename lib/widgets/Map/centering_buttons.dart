import 'package:flutter/material.dart';

class CenteringButtons extends StatelessWidget {
  final bool isLoadingUserLocation;
  final VoidCallback? onCenterOnUser;
  final bool userLocationAvailable;
  final VoidCallback? onCenterOnDevice;
  final bool deviceLocationAvailable;

  const CenteringButtons({
    super.key,
    required this.isLoadingUserLocation,
    required this.onCenterOnUser,
    required this.userLocationAvailable,
    required this.onCenterOnDevice,
    required this.deviceLocationAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCenteringButton(
          context: context,
          tooltip: 'Center map on your location',
          onTap: isLoadingUserLocation ? null : onCenterOnUser,
          child:
              isLoadingUserLocation
                  ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  )
                  : Icon(
                    Icons.person_pin_circle_outlined,
                    color:
                        userLocationAvailable
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 28,
                    semanticLabel: 'Center map on your location',
                  ),
        ),
        const SizedBox(height: 12),
        _buildCenteringButton(
          context: context,
          tooltip: 'Center map on vehicle location',
          onTap: deviceLocationAvailable ? onCenterOnDevice : null,
          child: Icon(
            Icons.two_wheeler_outlined,
            color:
                deviceLocationAvailable
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
            size: 28,
            semanticLabel: 'Center map on vehicle location',
          ),
        ),
      ],
    );
  }

  Widget _buildCenteringButton({
    required BuildContext context,
    required String tooltip,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: onTap,
            splashColor: colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: colorScheme.primary.withValues(alpha: 0.05),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class MapActionButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onRefresh;
  final bool isLoadingGeofences;
  final VoidCallback? onToggleGeofenceOverlay;
  final bool showGeofences;
  final bool hasGPSData;
  final VoidCallback? onShowNoGPSDetails;
  // final Widget userMenu;

  const MapActionButtons({
    super.key,
    required this.isLoading,
    required this.onRefresh,
    required this.isLoadingGeofences,
    required this.onToggleGeofenceOverlay,
    required this.showGeofences,
    required this.hasGPSData,
    required this.onShowNoGPSDetails,
    // required this.userMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        _buildFloatingButton(
          tooltip: 'Refresh Map',
          icon:
              isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  )
                  : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
          onPressed: isLoading ? null : onRefresh,
        ),
        const SizedBox(width: 10),
        _buildFloatingButton(
          tooltip: showGeofences ? 'Hide Geofences' : 'Show Geofences',
          icon:
              isLoadingGeofences
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  )
                  : Icon(
                    Icons.layers_rounded,
                    color: showGeofences ? AppColors.primaryBlue : Colors.black,
                    size: 22,
                  ),
          onPressed: isLoadingGeofences ? null : onToggleGeofenceOverlay,
        ),
        if (!hasGPSData) ...[
          const SizedBox(width: 10),
          _buildFloatingButton(
            tooltip: 'Show GPS Info',
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.warning,
              size: 22,
            ),
            onPressed: onShowNoGPSDetails,
          ),
        ],
        // const SizedBox(width: 10),
        // userMenu,
      ],
    );
  }

  Widget _buildFloatingButton({
    required Widget icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.14),
              width: 1,
            ),
          ),
          child: Tooltip(
            message: tooltip,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

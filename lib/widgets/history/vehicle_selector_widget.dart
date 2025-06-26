import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';
import '../../theme/app_colors.dart';

class VehicleSelectorWidget extends StatelessWidget {
  final vehicle? selectedVehicle;
  final List<vehicle> availableVehicles;
  final bool isLoadingVehicles;
  final VoidCallback onTap;

  const VehicleSelectorWidget({
    super.key,
    required this.selectedVehicle,
    required this.availableVehicles,
    required this.isLoadingVehicles,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.two_wheeler,
                color: AppColors.primaryBlue,
                size: 23,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                    child: Text(
                      isLoadingVehicles
                          ? 'Loading vehicles...'
                          : selectedVehicle?.name ?? 'No vehicle selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selectedVehicle?.plateNumber?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        selectedVehicle!.plateNumber!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (availableVehicles.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                  label: Text(
                    'Change',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryBlue, width: 1.2),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              )
            else if (availableVehicles.length == 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Only Vehicle',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class VehicleEmptyStateWidget extends StatelessWidget {
  final VoidCallback? onAddVehicle;

  const VehicleEmptyStateWidget({super.key, this.onAddVehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.two_wheeler_outlined,
              size: 40,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Vehicles Found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please add a vehicle first to view driving history.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onAddVehicle != null) ...[
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onAddVehicle,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                elevation: 1.5,
              ),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add Vehicle'),
            ),
          ],
        ],
      ),
    );
  }
}

class VehicleSelectionPromptWidget extends StatelessWidget {
  const VehicleSelectionPromptWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.touch_app_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a Vehicle',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a vehicle to view its driving history.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

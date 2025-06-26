import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';
import '../../theme/app_colors.dart';

class VehicleSelectionModal extends StatelessWidget {
  final List<vehicle> availableVehicles;
  final vehicle? selectedVehicle;
  final bool isLoadingVehicles;
  final Function(vehicle) onVehicleSelected;

  const VehicleSelectionModal({
    super.key,
    required this.availableVehicles,
    required this.selectedVehicle,
    required this.isLoadingVehicles,
    required this.onVehicleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Select Vehicle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 22),
                  splashRadius: 22,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 0, thickness: 1),
          Expanded(
            child:
                isLoadingVehicles
                    ? const Center(child: CircularProgressIndicator())
                    : availableVehicles.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildVehicleList(theme, context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 44,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No vehicles found',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList(ThemeData theme, BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: availableVehicles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final vehicle = availableVehicles[index];
        final isSelected = selectedVehicle?.id == vehicle.id;

        return Material(
          color:
              isSelected
                  ? AppColors.primaryBlue.withOpacity(0.07)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () {
              onVehicleSelected(vehicle);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color:
                      isSelected
                          ? AppColors.primaryBlue
                          : AppColors.border.withOpacity(0.18),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.primaryBlue
                              : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: isSelected ? Colors.white : AppColors.textTertiary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (vehicle.plateNumber?.isNotEmpty == true)
                          Text(
                            'Plate: ${vehicle.plateNumber}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (vehicle.vehicleTypes?.isNotEmpty == true)
                          Text(
                            'Type: ${vehicle.vehicleTypes}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

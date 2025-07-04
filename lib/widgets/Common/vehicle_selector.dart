import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';

/// A reusable dropdown button widget for vehicle selection
class VehicleDropdownSelector extends StatelessWidget {
  final vehicle? selectedVehicle;
  final List<vehicle> availableVehicles;
  final bool isLoading;
  final Function(vehicle) onVehicleSelected;
  final String? hint;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? dropdownColor;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;

  const VehicleDropdownSelector({
    Key? key,
    required this.selectedVehicle,
    required this.availableVehicles,
    required this.onVehicleSelected,
    this.isLoading = false,
    this.hint,
    this.padding,
    this.backgroundColor,
    this.dropdownColor,
    this.textStyle,
    this.hintStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child:
          isLoading
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading vehicles...',
                    style:
                        hintStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                  ),
                ],
              )
              : DropdownButtonHideUnderline(
                child: DropdownButton<vehicle>(
                  value: selectedVehicle,
                  hint: Text(
                    hint ?? 'Select a vehicle',
                    style:
                        hintStyle ??
                        theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                  ),
                  style: textStyle ?? theme.textTheme.bodyMedium,
                  dropdownColor: dropdownColor ?? theme.cardColor,
                  items:
                      availableVehicles.map((vehicle vehicleItem) {
                        return DropdownMenuItem<vehicle>(
                          value: vehicleItem,
                          child: Row(
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      vehicleItem.name,
                                      style:
                                          textStyle ??
                                          theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (vehicleItem.plateNumber != null &&
                                        vehicleItem.plateNumber!.isNotEmpty)
                                      Text(
                                        vehicleItem.plateNumber!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged:
                      availableVehicles.isEmpty
                          ? null
                          : (vehicle? selected) {
                            if (selected != null) {
                              onVehicleSelected(selected);
                            }
                          },
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: theme.iconTheme.color,
                  ),
                ),
              ),
    );
  }
}

/// A card-style vehicle selector with additional information
class VehicleCardSelector extends StatelessWidget {
  final vehicle? selectedVehicle;
  final List<vehicle> availableVehicles;
  final bool isLoading;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const VehicleCardSelector({
    Key? key,
    required this.selectedVehicle,
    required this.availableVehicles,
    required this.onTap,
    this.isLoading = false,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      isLoading
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading vehicles...',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          )
                          : selectedVehicle != null
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedVehicle!.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (selectedVehicle!.plateNumber != null &&
                                      selectedVehicle!
                                          .plateNumber!
                                          .isNotEmpty) ...[
                                    Text(
                                      selectedVehicle!.plateNumber!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.hintColor),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: theme.hintColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    '${availableVehicles.length} vehicles available',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select a vehicle',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${availableVehicles.length} vehicles available',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                ),
                Icon(Icons.keyboard_arrow_down, color: theme.iconTheme.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact vehicle info chip for display purposes
class VehicleInfoChip extends StatelessWidget {
  final vehicle vehicleData;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showPlateNumber;
  final EdgeInsetsGeometry? padding;

  const VehicleInfoChip({
    Key? key,
    required this.vehicleData,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.showPlateNumber = true,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: backgroundColor ?? theme.primaryColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car,
                size: 16,
                color: textColor ?? theme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                vehicleData.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor ?? theme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showPlateNumber &&
                  vehicleData.plateNumber != null &&
                  vehicleData.plateNumber!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '•',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        textColor ?? theme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  vehicleData.plateNumber!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        textColor ?? theme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

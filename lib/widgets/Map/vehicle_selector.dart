import 'package:flutter/material.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';

class VehicleSelectorBottomSheet extends StatelessWidget {
  final List<vehicle> availableVehicles;
  final bool isLoadingVehicles;
  final Future<bool> Function(vehicle) isVehicleSelected;
  final void Function(String deviceId, String vehicleName) onSwitchToVehicle;
  final void Function(String vehicleId) onAttachToDevice;
  final VoidCallback onAddDevice;
  final DeviceService deviceService;

  const VehicleSelectorBottomSheet({
    super.key,
    required this.availableVehicles,
    required this.isLoadingVehicles,
    required this.isVehicleSelected,
    required this.onSwitchToVehicle,
    required this.onAttachToDevice,
    required this.onAddDevice,
    required this.deviceService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(colorScheme),
          _buildHeader(context, theme, colorScheme),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          _buildContent(context, theme, colorScheme),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  /// Helper method to get device name by ID
  Future<String> _getDeviceName(String deviceId) async {
    try {
      final device = await deviceService.getDeviceById(deviceId);
      return device?.name ?? 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  Widget _buildDragHandle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: 48,
      height: 4,
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.two_wheeler,
              size: 24,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Vehicle',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Choose a vehicle to track',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceVariant.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (isLoadingVehicles) {
      return _buildLoadingState(colorScheme);
    }

    if (availableVehicles.isEmpty) {
      return _buildEmptyState(context, theme, colorScheme);
    }

    return _buildVehicleList(context, theme, colorScheme);
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text(
            'Loading vehicles...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.two_wheeler,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No vehicles available',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a GPS device to start tracking your vehicles',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddDevice,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Device'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final vehiclesWithDevice =
        availableVehicles
            .where((v) => v.deviceId != null && v.deviceId!.isNotEmpty)
            .toList();

    final vehiclesWithoutDevice =
        availableVehicles
            .where((v) => v.deviceId == null || v.deviceId!.isEmpty)
            .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehiclesWithDevice.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Available Vehicles',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700.withValues(alpha: 0.8),
                  ),
                ),
              ),
              ...vehiclesWithDevice.map(
                (vehicle) => _buildVehicleItem(
                  context,
                  theme,
                  colorScheme,
                  vehicle,
                  true,
                ),
              ),
            ],
            if (vehiclesWithoutDevice.isNotEmpty) ...[
              if (vehiclesWithDevice.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Unattached Vehicles',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ...vehiclesWithoutDevice.map(
                (vehicle) => _buildVehicleItem(
                  context,
                  theme,
                  colorScheme,
                  vehicle,
                  false,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            _buildAddDeviceItem(context, theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    vehicle vehicle,
    bool hasDevice,
  ) {
    if (hasDevice) {
      return FutureBuilder<bool>(
        future: isVehicleSelected(vehicle),
        builder: (context, snapshot) {
          final isSelected = snapshot.data ?? false;
          return _buildConnectedVehicleTile(
            context,
            theme,
            colorScheme,
            vehicle,
            isSelected,
          );
        },
      );
    } else {
      return _buildUnattachedVehicleTile(context, theme, colorScheme, vehicle);
    }
  }

  Widget _buildConnectedVehicleTile(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    vehicle vehicle,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color:
            isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.1)
                : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (!isSelected && vehicle.deviceId != null) {
              onSwitchToVehicle(vehicle.deviceId!, vehicle.name);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primary.withValues(alpha: 0.1)
                            : colorScheme.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.two_wheeler,
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (vehicle.plateNumber != null &&
                          vehicle.plateNumber!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vehicle.plateNumber!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (vehicle.deviceId != null)
                        FutureBuilder<String>(
                          future: _getDeviceName(vehicle.deviceId!),
                          builder: (context, snapshot) {
                            final deviceName = snapshot.data ?? 'Loading...';
                            return Text(
                              'Device: $deviceName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border:
                        isSelected
                            ? null
                            : Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.5),
                              width: 2,
                            ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : null,
                    color: colorScheme.onPrimary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnattachedVehicleTile(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    vehicle vehicle,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Close the bottom sheet
            onAttachToDevice(vehicle.id); // Navigate or attach logic
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.link_off_rounded,
                    color: colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (vehicle.plateNumber != null &&
                          vehicle.plateNumber!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vehicle.plateNumber!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Attach to a Device',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.error,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDeviceItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onAddDevice,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Device',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up a new GPS device for tracking',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

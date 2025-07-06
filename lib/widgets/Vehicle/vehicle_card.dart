import 'package:flutter/material.dart';
import '../../models/Device/device.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/device/deviceService.dart';
import '../Common/confirmation_dialog.dart';
import '../../theme/app_colors.dart';

// --- FIXED VehicleCard class ---
class VehicleCard extends StatelessWidget {
  final vehicle vehicleModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final DeviceService deviceService;

  const VehicleCard({
    Key? key,
    required this.vehicleModel,
    required this.onEdit,
    required this.onDelete,
    required this.deviceService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(vehicleModel.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) => _showDeleteConfirmation(context),
      onDismissed: (_) => onDelete(),
      child: Card(
        elevation: 3,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onEdit(), // Make the entire card tappable to edit
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  _buildInfoSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return ConfirmationDialog.show(
      context: context,
      title: 'Delete Vehicle',
      content:
          'Are you sure you want to delete "${vehicleModel.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                vehicleModel.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: Colors.teal, size: 22),
              onPressed: onEdit,
              tooltip: 'Edit Vehicle',
              style: IconButton.styleFrom(
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Device information with full width
        _buildDeviceStatus(),
      ],
    );
  }

  Widget _buildDeviceStatus() {
    if (vehicleModel.deviceId != null) {
      return StreamBuilder<Device?>(
        stream: deviceService.getDeviceStream(vehicleModel.deviceId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final device = snapshot.data!;
            return _buildDeviceStatusContainer(
              icon: Icons.device_hub_rounded,
              text: 'Attached to Device : ${device.name}',
              color: AppColors.success,
            );
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildDeviceStatusContainer(
              icon: Icons.device_hub_rounded,
              text: 'Loading device...',
              color: Colors.grey,
            );
          } else {
            return _buildDeviceStatusContainer(
              icon: Icons.link_off_rounded,
              text: "This vehicle isn't attached to any device yet.",
              color: AppColors.error,
            );
          }
        },
      );
    } else {
      return _buildDeviceStatusContainer(
        icon: Icons.link_off_rounded,
        text: "This vehicle isn't attached to any device yet.",
        color: AppColors.error,
      );
    }
  }

  Widget _buildDeviceStatusContainer({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasVehicleDetails =
        vehicleModel.plateNumber != null || vehicleModel.vehicleTypes != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          // License plate and vehicle type section
          if (hasVehicleDetails) ...[
            Row(
              children: [
                if (vehicleModel.plateNumber != null) ...[
                  Expanded(
                    child: _buildInfoRow(
                      context,
                      Icons.confirmation_number_rounded,
                      'License Plate',
                      vehicleModel.plateNumber!,
                      Colors.black,
                    ),
                  ),
                  if (vehicleModel.vehicleTypes != null)
                    const SizedBox(width: 20),
                ],
                if (vehicleModel.vehicleTypes != null)
                  Expanded(
                    child: _buildInfoRow(
                      context,
                      Icons.category_rounded,
                      'Vehicle Type',
                      vehicleModel.vehicleTypes!,
                      theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 16),
          ],
          // Created and updated dates section
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.calendar_today_rounded,
                  'Created at',
                  _formatDate(vehicleModel.createdAt),
                  Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.update_rounded,
                  'Updated at',
                  _formatDate(vehicleModel.updatedAt),
                  Colors.blueGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Container(
        //   padding: const EdgeInsets.all(7),
        //   decoration: BoxDecoration(
        //     color: color.withValues(alpha: 0.1),
        //     borderRadius: BorderRadius.circular(8),
        //   ),
        //   child: Icon(icon, size: 16, color: color),
        // ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}

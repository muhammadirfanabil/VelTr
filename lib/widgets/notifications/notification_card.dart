import 'package:flutter/material.dart';
import '../../models/notifications/unified_notification.dart';
import '../../utils/time_formatter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

/// Reusable widget for displaying a single notification card
class NotificationCard extends StatelessWidget {
  final UnifiedNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteOption;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
    this.onDelete,
    this.showDeleteOption = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: showDeleteOption ? _buildDismissibleCard() : _buildCard(),
    );
  }

  Widget _buildDismissibleCard() {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation();
      },
      onDismissed: (direction) {
        onDelete?.call();
      },
      background: _buildDeleteBackground(),
      child: _buildCard(),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.delete, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            _buildStatusIcon(),
            const SizedBox(width: 16),
            Expanded(child: _buildContent()),
            _buildActionIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [notification.color, notification.color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: notification.color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(notification.icon, color: Colors.white, size: 24),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBadge(),
        const SizedBox(height: 8),
        _buildTitle(),
        const SizedBox(height: 4),
        _buildMessage(),
        if (notification.hasLocation) ...[
          const SizedBox(height: 6),
          _buildLocation(),
        ],
        const SizedBox(height: 6),
        _buildTimestamp(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: notification.badgeColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        notification.badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: notification.badgeTextColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      notification.title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMessage() {
    return Text(
      notification.message,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            notification.formattedLocation ?? '',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimestamp() {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          TimeFormatter.getTimeAgo(notification.timestamp),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionIndicator() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.keyboard_arrow_right_rounded,
        color: AppColors.textTertiary,
        size: 20,
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation() async {
    // This would typically show a dialog, but for now we'll return true
    // In a real implementation, you'd want to show a proper confirmation dialog
    return true;
  }
}

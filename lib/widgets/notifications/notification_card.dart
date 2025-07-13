import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notifications/unified_notification.dart';
import '../../utils/time_formatter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

import '../../widgets/Common/confirmation_dialog.dart';

class NotificationCard extends StatelessWidget {
  final UnifiedNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDeleteOption;
  final bool showTimestamp;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
    this.onDelete,
    this.showDeleteOption = true,
    this.showTimestamp = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTimestamp)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 7),
            child: Text(
              _formatTimeHeader(notification.timestamp),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary.withValues(alpha: 0.64),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          child:
              showDeleteOption ? _buildDismissibleCard(context) : _buildCard(),
        ),
      ],
    );
  }

  String _formatTimeHeader(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  Widget _buildDismissibleCard(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context);
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
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(AppIcons.delete, color: Colors.white, size: 24),
          const SizedBox(width: 6),
          const Text(
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color:
                notification.isRead
                    ? AppColors.surface
                    : AppColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color:
                  notification.borderColor != null
                      ? (notification.isRead
                          ? notification.borderColor!.withValues(alpha: 0.5)
                          : notification.borderColor!.withValues(alpha: 0.8))
                      : (notification.isRead
                          ? AppColors.border.withValues(alpha: 0.75)
                          : notification.color.withValues(alpha: 0.26)),
              width:
                  notification.borderColor != null
                      ? (notification.isRead ? 1.0 : 1.5)
                      : (notification.isRead ? 0.5 : 1.0),
            ),
          ),
          child: Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 14),
              Expanded(child: _buildContent()),
              _buildActionIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            notification.color,
            notification.color.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: notification.color.withValues(alpha: 0.21),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(notification.icon, color: Colors.white, size: 22),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBadge(),
        const SizedBox(height: 6),
        _buildTitle(),
        const SizedBox(height: 3),
        _buildMessage(),
        if (notification.hasLocation) ...[
          const SizedBox(height: 4),
          _buildLocation(),
        ],
        const SizedBox(height: 5),
        _buildDetailedTimestamp(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: notification.badgeColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        notification.badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: notification.badgeTextColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      notification.title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
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
        fontSize: 13.2,
        color: AppColors.textSecondary,
        fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w500,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            notification.formattedLocation ?? '',
            style: TextStyle(
              fontSize: 12.3,
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

  Widget _buildDetailedTimestamp() {
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(
          TimeFormatter.getTimeAgo(notification.timestamp),
          style: TextStyle(
            fontSize: 12.3,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionIndicator() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        Icons.keyboard_arrow_left,
        color: AppColors.textTertiary,
        size: 18,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Notification',
      content:
          'Are you sure you want to delete this notification? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );

    return confirmed == true;
  }
}

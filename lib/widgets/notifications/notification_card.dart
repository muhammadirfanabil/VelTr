import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notifications/unified_notification.dart';
import '../../utils/time_formatter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/notification_styles.dart';

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
            padding: NotificationStyles.timeHeaderPadding,
            child: Text(
              _formatTimeHeader(notification.timestamp),
              style: NotificationStyles.getTimeHeaderTextStyle(),
            ),
          ),
        Container(
          margin: NotificationStyles.cardMargin,
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
      padding: NotificationStyles.deleteBackgroundPadding,
      decoration: NotificationStyles.getDeleteBackgroundDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            AppIcons.delete,
            color: Colors.white,
            size: NotificationStyles.deleteIconSize,
          ),
          const SizedBox(width: NotificationStyles.deleteIconTextSpacing),
          const Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: NotificationStyles.deleteTextFontSize,
              fontWeight: NotificationStyles.deleteTextFontWeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    // Get centralized border styling
    final borderStyle = AppColors.getNotificationBorderStyle(
      isRead: notification.isRead,
      borderColor: notification.borderColor,
      fallbackColor: notification.color,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(NotificationStyles.cardBorderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(
          NotificationStyles.cardBorderRadius,
        ),
        onTap: onTap,
        child: Container(
          padding: NotificationStyles.cardPadding,
          decoration: BoxDecoration(
            color: NotificationStyles.getCardBackgroundColor(
              notification.isRead,
            ),
            borderRadius: BorderRadius.circular(
              NotificationStyles.cardBorderRadius,
            ),
            boxShadow: NotificationStyles.getCardShadow(),
            border: Border.all(
              color: borderStyle['color'] as Color,
              width: borderStyle['width'] as double,
            ),
          ),
          child: Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: NotificationStyles.iconContentSpacing),
              Expanded(child: _buildContent()),
              // Action indicator removed - no functionality assigned
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Container(
      width: NotificationStyles.iconContainerSize,
      height: NotificationStyles.iconContainerSize,
      decoration: NotificationStyles.getIconContainerDecoration(
        notification.color,
      ),
      child: Icon(
        notification.icon,
        color: Colors.white,
        size: NotificationStyles.iconSize,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBadge(),
        const SizedBox(height: NotificationStyles.badgeToTitleSpacing),
        _buildTitle(),
        const SizedBox(height: NotificationStyles.titleToMessageSpacing),
        _buildMessage(),
        if (notification.hasLocation) ...[
          const SizedBox(height: NotificationStyles.messageToLocationSpacing),
          _buildLocation(),
        ],
        const SizedBox(height: NotificationStyles.locationToTimestampSpacing),
        _buildDetailedTimestamp(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: NotificationStyles.badgePadding,
      decoration: BoxDecoration(
        color: notification.badgeColor,
        borderRadius: BorderRadius.circular(
          NotificationStyles.badgeBorderRadius,
        ),
      ),
      child: Text(
        notification.badgeText,
        style: NotificationStyles.getBadgeTextStyle(
          notification.badgeTextColor,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      notification.title,
      style: NotificationStyles.getTitleTextStyle(notification.isRead),
      maxLines: NotificationStyles.titleMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMessage() {
    return Text(
      notification.message,
      style: NotificationStyles.getMessageTextStyle(notification.isRead),
      maxLines: NotificationStyles.messageMaxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(
          Icons.location_on_rounded,
          size: NotificationStyles.metadataIconSize,
          color: Colors.grey[500],
        ),
        const SizedBox(width: NotificationStyles.metadataIconSpacing),
        Expanded(
          child: Text(
            notification.formattedLocation ?? '',
            style: NotificationStyles.getMetadataTextStyle(),
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
        Icon(
          Icons.access_time_rounded,
          size: NotificationStyles.metadataIconSize,
          color: Colors.grey[500],
        ),
        const SizedBox(width: NotificationStyles.metadataIconSpacing),
        Text(
          TimeFormatter.getTimeAgo(notification.timestamp),
          style: NotificationStyles.getMetadataTextStyle(),
        ),
      ],
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

import 'package:intl/intl.dart';
import '../notifications/unified_notification.dart';

/// Enumeration for date group types
enum DateGroupType {
  today,
  yesterday,
  thisWeek,
  older;

  String getTitle(DateTime date) {
    switch (this) {
      case DateGroupType.today:
        return 'Today';
      case DateGroupType.yesterday:
        return 'Yesterday';
      case DateGroupType.thisWeek:
        return DateFormat('EEEE').format(date);
      case DateGroupType.older:
        return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

/// Model for grouping notifications by date
class NotificationDateGroup {
  final String title;
  final DateTime date;
  final DateGroupType type;
  final List<UnifiedNotification> notifications;

  const NotificationDateGroup({
    required this.title,
    required this.date,
    required this.type,
    required this.notifications,
  });

  /// Factory constructor to create a date group from notifications
  factory NotificationDateGroup.fromNotifications({
    required DateTime date,
    required List<UnifiedNotification> notifications,
  }) {
    final now = DateTime.now();
    DateGroupType type;

    if (_isSameDay(date, now)) {
      type = DateGroupType.today;
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      type = DateGroupType.yesterday;
    } else if (now.difference(date).inDays < 7) {
      type = DateGroupType.thisWeek;
    } else {
      type = DateGroupType.older;
    }

    // Sort notifications by timestamp (newest first)
    final sortedNotifications = List<UnifiedNotification>.from(notifications)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return NotificationDateGroup(
      title: type.getTitle(date),
      date: date,
      type: type,
      notifications: sortedNotifications,
    );
  }

  /// Check if two dates are the same day
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get the number of unread notifications in this group
  int get unreadCount {
    return notifications.where((notification) => !notification.isRead).length;
  }

  /// Get the number of total notifications in this group
  int get totalCount => notifications.length;

  /// Check if this group has any notifications
  bool get hasNotifications => notifications.isNotEmpty;

  /// Get notifications by type
  List<UnifiedNotification> getNotificationsByType(NotificationType type) {
    return notifications
        .where((notification) => notification.type == type)
        .toList();
  }

  /// Get only geofence notifications
  List<UnifiedNotification> get geofenceNotifications {
    return getNotificationsByType(NotificationType.geofence);
  }

  /// Get only general notifications
  List<UnifiedNotification> get generalNotifications {
    return getNotificationsByType(NotificationType.general);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date.toIso8601String(),
      'type': type.name,
      'notifications': notifications.map((n) => n.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'NotificationDateGroup(title: $title, date: $date, count: ${notifications.length})';
  }
}

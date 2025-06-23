import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/notifications/unified_notification.dart';
import '../../models/notifications/notification_date_group.dart';
import '../auth/authService.dart';

/// Service for managing unified notifications (geofence alerts + general notifications)
class UnifiedNotificationService {
  static final UnifiedNotificationService _instance =
      UnifiedNotificationService._internal();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _generalNotificationsCollection = 'notifications';
  static const String _userAlertsCollection = 'user_alerts';
  static const String _geofenceAlertsSubcollection = 'geofence_alerts';

  /// Current user ID
  String? get _currentUserId => AuthService.getCurrentUserId();

  /// Get stream of all notifications
  Stream<List<UnifiedNotification>> getNotificationsStream() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _getCombinedNotificationsStream();
  }

  /// Get notifications grouped by date
  Stream<List<NotificationDateGroup>> getGroupedNotificationsStream() {
    return getNotificationsStream().map((notifications) {
      return _groupNotificationsByDate(notifications);
    });
  }

  /// Get combined notifications from both sources
  Stream<List<UnifiedNotification>> _getCombinedNotificationsStream() async* {
    if (_currentUserId == null) {
      yield [];
      return;
    }

    // Use a timer to periodically fetch and combine data
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        final notifications = await _fetchCombinedNotifications();
        yield notifications;
      } catch (e) {
        debugPrint('Error fetching notifications: $e');
        yield [];
      }
    }
  }

  /// Fetch and combine notifications from both sources
  Future<List<UnifiedNotification>> _fetchCombinedNotifications() async {
    final List<UnifiedNotification> notifications = [];

    try {
      // Fetch general notifications
      final generalNotifications = await _fetchGeneralNotifications();
      notifications.addAll(generalNotifications);

      // Fetch geofence alerts
      final geofenceNotifications = await _fetchGeofenceNotifications();
      notifications.addAll(geofenceNotifications);

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error fetching combined notifications: $e');
    }

    return notifications;
  }

  /// Fetch general notifications
  Future<List<UnifiedNotification>> _fetchGeneralNotifications() async {
    try {
      final snapshot =
          await _firestore
              .collection(_generalNotificationsCollection)
              .orderBy('waktu', descending: true)
              .limit(100)
              .get();

      return snapshot.docs.map((doc) {
        return UnifiedNotification.fromFirestore(
          id: doc.id,
          data: doc.data(),
          type: NotificationType.general,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching general notifications: $e');
      return [];
    }
  }

  /// Fetch geofence alerts
  Future<List<UnifiedNotification>> _fetchGeofenceNotifications() async {
    if (_currentUserId == null) return [];

    try {
      final snapshot =
          await _firestore
              .collection(_userAlertsCollection)
              .doc(_currentUserId!)
              .collection(_geofenceAlertsSubcollection)
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      return snapshot.docs.map((doc) {
        return UnifiedNotification.fromFirestore(
          id: doc.id,
          data: doc.data(),
          type: NotificationType.geofence,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching geofence notifications: $e');
      return [];
    }
  }

  /// Group notifications by date
  List<NotificationDateGroup> _groupNotificationsByDate(
    List<UnifiedNotification> notifications,
  ) {
    final Map<String, List<UnifiedNotification>> grouped = {};

    for (final notification in notifications) {
      final date = notification.timestamp;
      final key = _getDateKey(date);
      grouped.putIfAbsent(key, () => []).add(notification);
    }

    // Convert to date groups and sort
    final groups =
        grouped.entries.map((entry) {
          final firstNotification = entry.value.first;
          return NotificationDateGroup.fromNotifications(
            date: firstNotification.timestamp,
            notifications: entry.value,
          );
        }).toList();

    // Sort groups by date (newest first)
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  /// Generate date key for grouping
  String _getDateKey(DateTime date) {
    final now = DateTime.now();

    if (_isSameDay(date, now)) {
      return 'today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'yesterday';
    } else if (now.difference(date).inDays < 7) {
      return 'thisweek_${date.weekday}';
    } else {
      return '${date.year}-${date.month}-${date.day}';
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Mark notification as read
  Future<void> markAsRead(UnifiedNotification notification) async {
    try {
      if (notification.type == NotificationType.geofence) {
        await _markGeofenceNotificationAsRead(notification.id);
      } else {
        await _markGeneralNotificationAsRead(notification.id);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark general notification as read
  Future<void> _markGeneralNotificationAsRead(String notificationId) async {
    await _firestore
        .collection(_generalNotificationsCollection)
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark geofence notification as read
  Future<void> _markGeofenceNotificationAsRead(String notificationId) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection(_userAlertsCollection)
        .doc(_currentUserId!)
        .collection(_geofenceAlertsSubcollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Delete a specific notification
  Future<void> deleteNotification(UnifiedNotification notification) async {
    try {
      if (notification.type == NotificationType.geofence) {
        await _deleteGeofenceNotification(notification.id);
      } else {
        await _deleteGeneralNotification(notification.id);
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Delete general notification
  Future<void> _deleteGeneralNotification(String notificationId) async {
    await _firestore
        .collection(_generalNotificationsCollection)
        .doc(notificationId)
        .delete();
  }

  /// Delete geofence notification
  Future<void> _deleteGeofenceNotification(String notificationId) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection(_userAlertsCollection)
        .doc(_currentUserId!)
        .collection(_geofenceAlertsSubcollection)
        .doc(notificationId)
        .delete();
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    if (_currentUserId == null) return;

    try {
      final batch = _firestore.batch();

      // Clear general notifications
      final generalSnapshot =
          await _firestore.collection(_generalNotificationsCollection).get();

      for (final doc in generalSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Clear geofence alerts
      final geofenceSnapshot =
          await _firestore
              .collection(_userAlertsCollection)
              .doc(_currentUserId!)
              .collection(_geofenceAlertsSubcollection)
              .get();

      for (final doc in geofenceSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
      rethrow;
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final notifications = await _fetchCombinedNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get unread count stream
  Stream<int> getUnreadCountStream() {
    return getNotificationsStream().map((notifications) {
      return notifications.where((n) => !n.isRead).length;
    });
  }

  /// Create a new geofence alert notification
  Future<void> createGeofenceAlert({
    required String deviceId,
    required String deviceName,
    required String geofenceName,
    required GeofenceAction action,
    required double latitude,
    required double longitude,
  }) async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection(_userAlertsCollection)
          .doc(_currentUserId!)
          .collection(_geofenceAlertsSubcollection)
          .add({
            'deviceId': deviceId,
            'deviceName': deviceName,
            'geofenceName': geofenceName,
            'action': action.name,
            'timestamp': FieldValue.serverTimestamp(),
            'latitude': latitude,
            'longitude': longitude,
            'isRead': false,
          });
    } catch (e) {
      debugPrint('Error creating geofence alert: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    // Resources are automatically managed by Firestore
  }
}

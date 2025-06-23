import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../constants/app_constants.dart';
import '../../widgets/Common/stickyFooter.dart';
import '../../widgets/Common/confirmation_dialog.dart';

// Unified notification model to combine all notification types
class UnifiedNotification {
  final String id;
  final String type; // 'geofence' or 'general'
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isRead;

  UnifiedNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.data,
    this.isRead = false,
  });

  IconData get icon {
    if (type == 'geofence') {
      final action = data['action'] ?? '';
      return action == 'enter' ? Icons.login_rounded : Icons.logout_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color get color {
    if (type == 'geofence') {
      final action = data['action'] ?? '';
      return action == 'enter'
          ? const Color(0xFF10B981)
          : const Color(0xFFEF4444);
    }
    return const Color(0xFF3B82F6);
  }

  String get badgeText {
    if (type == 'geofence') {
      final action = data['action'] ?? '';
      return action == 'enter' ? 'ENTERED' : 'EXITED';
    }
    return 'NOTIFICATION';
  }

  Color get badgeColor {
    if (type == 'geofence') {
      final action = data['action'] ?? '';
      return action == 'enter'
          ? const Color(0xFFD1FAE5)
          : const Color(0xFFFEE2E2);
    }
    return const Color(0xFFDEEBFF);
  }

  Color get badgeTextColor {
    if (type == 'geofence') {
      final action = data['action'] ?? '';
      return action == 'enter'
          ? const Color(0xFF065F46)
          : const Color(0xFF991B1B);
    }
    return const Color(0xFF1565C0);
  }
}

// Date group for organizing notifications
class NotificationDateGroup {
  final String title;
  final DateTime date;
  final List<UnifiedNotification> notifications;

  NotificationDateGroup({
    required this.title,
    required this.date,
    required this.notifications,
  });
}

class EnhancedNotificationsScreen extends StatefulWidget {
  const EnhancedNotificationsScreen({super.key});

  @override
  State<EnhancedNotificationsScreen> createState() =>
      _EnhancedNotificationsScreenState();
}

class _EnhancedNotificationsScreenState
    extends State<EnhancedNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed:
              () => Navigator.pushReplacementNamed(
                context,
                AppConstants.trackVehicleRoute,
              ),
        ),
        title: const Center(
          child: Text(
            'Notifications',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Colors.black,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          StreamBuilder<List<UnifiedNotification>>(
            stream: _getCombinedNotificationsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                return IconButton(
                  onPressed: () => _showClearAllConfirmation(context),
                  icon: const Icon(Icons.clear_all, color: Color(0xFF64748B)),
                  tooltip: 'Clear all notifications',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.2)],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<UnifiedNotification>>(
                stream: _getCombinedNotificationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF3B82F6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading notifications...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Something went wrong',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Unable to load notifications. Please try again.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 64,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Geofence and system notifications will appear here\nwhen events occur in your GPS system',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final notifications = snapshot.data!;
                  final groupedNotifications = _groupNotificationsByDate(
                    notifications,
                  );

                  return ListView.builder(
                    padding: EdgeInsets.only(
                      top: 8,
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 96,
                    ),
                    itemCount: groupedNotifications.length,
                    itemBuilder: (context, index) {
                      final dateGroup = groupedNotifications[index];
                      return _buildDateGroup(dateGroup);
                    },
                  );
                },
              ),
            ),
            const StickyFooter(),
          ],
        ),
      ),
    );
  } // Get notifications from both general notifications and geofence alerts

  Stream<List<UnifiedNotification>> _getCombinedNotificationsStream() async* {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      yield [];
      return;
    }

    // Listen to both streams and combine results
    await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
      try {
        final List<UnifiedNotification> notifications = [];

        // Get general notifications
        final generalSnapshot =
            await FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('waktu', descending: true)
                .get();

        for (final doc in generalSnapshot.docs) {
          final data = doc.data();
          notifications.add(
            UnifiedNotification(
              id: doc.id,
              type: 'general',
              title: data['geofenceName'] ?? 'Notification',
              message: _formatGeneralNotificationMessage(data),
              timestamp:
                  (data['waktu'] as Timestamp?)?.toDate() ?? DateTime.now(),
              data: data,
              isRead: data['read'] ?? false,
            ),
          );
        }

        // Get geofence alerts
        final geofenceSnapshot =
            await FirebaseFirestore.instance
                .collection('user_alerts')
                .doc(currentUser.uid)
                .collection('geofence_alerts')
                .orderBy('timestamp', descending: true)
                .get();

        for (final doc in geofenceSnapshot.docs) {
          final data = doc.data();
          final deviceName = data['deviceName'] ?? 'Unknown Device';
          final geofenceName = data['geofenceName'] ?? 'Unknown Geofence';
          final action = data['action'] ?? 'unknown';

          notifications.add(
            UnifiedNotification(
              id: doc.id,
              type: 'geofence',
              title: geofenceName,
              message: _formatGeofenceMessage(deviceName, action, geofenceName),
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              data: data,
              isRead: data['isRead'] ?? false,
            ),
          );
        }

        // Sort by timestamp (newest first)
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        yield notifications;
      } catch (e) {
        debugPrint('Error loading notifications: $e');
        yield [];
      }
    }
  }

  String _formatGeneralNotificationMessage(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    final geofenceName = data['geofenceName'] ?? '';

    if (status == 'Masuk area' || status.toLowerCase().contains('enter')) {
      return 'Vehicle has entered $geofenceName';
    } else if (status.toLowerCase().contains('exit')) {
      return 'Vehicle has exited $geofenceName';
    }

    return status.isNotEmpty ? status : 'Geofence notification';
  }

  String _formatGeofenceMessage(
    String deviceName,
    String action,
    String geofenceName,
  ) {
    final actionText = action == 'enter' ? 'entered' : 'exited';
    return '$deviceName has $actionText $geofenceName';
  }

  List<NotificationDateGroup> _groupNotificationsByDate(
    List<UnifiedNotification> notifications,
  ) {
    final Map<String, List<UnifiedNotification>> grouped = {};
    final now = DateTime.now();

    for (final notification in notifications) {
      final date = notification.timestamp;
      String key;

      if (_isSameDay(date, now)) {
        key = 'today';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        key = 'yesterday';
      } else if (now.difference(date).inDays < 7) {
        key = 'thisweek_${date.weekday}';
      } else {
        key = DateFormat('yyyy-MM-dd').format(date);
      }

      grouped.putIfAbsent(key, () => []).add(notification);
    }

    // Convert to list and sort by date (newest first)
    final groups =
        grouped.entries.map((entry) {
          final firstNotification = entry.value.first;
          return NotificationDateGroup(
            title: _getGroupTitle(entry.key, firstNotification.timestamp),
            date: firstNotification.timestamp,
            notifications: entry.value,
          );
        }).toList();

    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  String _getGroupTitle(String key, DateTime date) {
    if (key == 'today') return 'Today';
    if (key == 'yesterday') return 'Yesterday';
    if (key.startsWith('thisweek_')) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateGroup(NotificationDateGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, top: 16, bottom: 8),
          child: Text(
            group.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...group.notifications.map(
          (notification) => _buildNotificationCard(notification),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildNotificationCard(UnifiedNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(context);
        },
        onDismissed: (direction) async {
          await _deleteNotification(notification.id, notification.type);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Notification deleted',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_rounded, color: Colors.white, size: 28),
              SizedBox(height: 4),
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
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
          ),
          child: Row(
            children: [
              // Enhanced Status Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      notification.color,
                      notification.color.withOpacity(0.8),
                    ],
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
              ),
              const SizedBox(width: 16),

              // Enhanced Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Message
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location info for geofence notifications
                    if (notification.type == 'geofence' &&
                        notification.data['latitude'] != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${notification.data['latitude']?.toStringAsFixed(4)}, ${notification.data['longitude']?.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Time with icon
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(notification.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return ConfirmationDialog.show(
      context: context,
      title: 'Delete Notification',
      content:
          'Are you sure you want to delete this notification? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: const Color(0xFFEF4444),
    );
  }

  Future<void> _showClearAllConfirmation(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Clear All Notifications',
      content:
          'Are you sure you want to delete all notifications? This action cannot be undone.',
      confirmText: 'Clear All',
      cancelText: 'Cancel',
      confirmColor: const Color(0xFFEF4444),
    );

    if (confirmed == true) {
      await _clearAllNotifications();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'All notifications cleared',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId, String type) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      if (type == 'geofence') {
        // Delete from geofence alerts collection
        await FirebaseFirestore.instance
            .collection('user_alerts')
            .doc(currentUser.uid)
            .collection('geofence_alerts')
            .doc(notificationId)
            .delete();
      } else {
        // Delete from general notifications collection
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final batch = FirebaseFirestore.instance.batch();

      // Clear general notifications
      final generalSnapshots =
          await FirebaseFirestore.instance.collection('notifications').get();

      for (final doc in generalSnapshots.docs) {
        batch.delete(doc.reference);
      }

      // Clear geofence alerts
      final geofenceSnapshots =
          await FirebaseFirestore.instance
              .collection('user_alerts')
              .doc(currentUser.uid)
              .collection('geofence_alerts')
              .get();

      for (final doc in geofenceSnapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }
}

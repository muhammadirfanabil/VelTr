import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import '../geofence/geofence_alert_service.dart'; // Import GeofenceAlertService

/// Enhanced notification service with FCM token management and geofence alerts
class EnhancedNotificationService {
  static final EnhancedNotificationService _instance =
      EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('✅ FCM Permission granted: ${settings.authorizationStatus}');

      // Note: FCM token management is now handled by AuthService
      // This service focuses on notification handling and display
      // Get FCM token for logging purposes only
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token available: ${token.substring(0, 20)}...');
      }

      // Note: Token refresh handling is now managed by AuthService

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification opened app
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);

      // Check for initial message when app was terminated
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpenedApp(initialMessage);
      }

      _isInitialized = true;
      debugPrint('✅ Enhanced Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_alerts',
      'Geofence Alerts',
      description: 'Notifications for geofence entry and exit events',
      importance: Importance.high,
      playSound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Handle notification tapped
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '📱 Foreground message received: ${message.notification?.title}',
    );
    debugPrint('📊 Message data: ${message.data}');

    // Handle geofence alerts by delegating to GeofenceAlertService
    if (message.data['type'] == 'geofence_alert') {
      debugPrint('🎯 Routing geofence alert to GeofenceAlertService');
      // Delegate to GeofenceAlertService instead of handling locally
      final geofenceService = GeofenceAlertService();
      geofenceService.handleFCMMessage(message); // We'll create this method
    } else {
      // Show local notification for non-geofence messages
      _showLocalNotification(message);
    }
  }

  /// Handle notification that opened the app
  void _handleNotificationOpenedApp(RemoteMessage message) {
    debugPrint(
      '🚀 App opened from notification: ${message.notification?.title}',
    );

    if (message.data['type'] == 'geofence_alert') {
      // Delegate navigation handling to GeofenceAlertService
      final geofenceService = GeofenceAlertService();
      geofenceService.handleNotificationTap(message);
    }
  }

  /// Handle notification data
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'geofence_alert':
        // Geofence alerts are handled by GeofenceAlertService
        debugPrint('🎯 Geofence alert data handled by GeofenceAlertService');
        break;
      default:
        debugPrint('🔔 Unknown notification type: $type');
    }
  }

  /// Show local notification for foreground messages (excludes geofence alerts)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final isGeofenceAlert = data['type'] == 'geofence_alert';

    // Skip geofence alerts - they're handled by GeofenceAlertService
    if (isGeofenceAlert) {
      debugPrint('🎯 Skipping local notification for geofence alert - handled by GeofenceAlertService');
      return;
    }

    // Handle other notification types
    String title = notification.title ?? 'GPS App';
    String body = notification.body ?? '';
    String payload = jsonEncode(data);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'general_notifications',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF2196F3),
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Get notification history stream
  Stream<QuerySnapshot> getNotificationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('notifications')
        .where('ownerId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Get unread notification count
  Stream<int> getUnreadNotificationCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final unreadNotifications =
          await _firestore
              .collection('notifications')
              .where('ownerId', isEqualTo: currentUser.uid)
              .where('read', isEqualTo: false)
              .get();

      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final notifications =
          await _firestore
              .collection('notifications')
              .where('ownerId', isEqualTo: currentUser.uid)
              .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ All notifications cleared');
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  /// Remove current FCM token (useful for logout)
  Future<void> removeFCMToken() async {
    try {
      final currentUser = _auth.currentUser;
      final token = await _messaging.getToken();

      if (currentUser != null && token != null) {
        await _firestore
            .collection('users_information')
            .doc(currentUser.uid)
            .update({
              'fcmTokens': FieldValue.arrayRemove([token]),
            });
        debugPrint('✅ FCM Token removed on logout');
      }
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getCurrentFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Test notification (for debugging)
  Future<void> sendTestNotification() async {
    await _localNotifications.show(
      999,
      '🧪 Test Notification',
      'This is a test notification from GPS App',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'geofence_alerts',
          'Geofence Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.notification?.title}');
  debugPrint('📊 Background message data: ${message.data}');

  // Handle background message if needed
  // Note: You can't update UI here, only process data
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

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

      // Get FCM token and save to Firestore
      await _updateFCMToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_saveFCMToken);

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

  /// Update FCM token in Firestore
  Future<void> _updateFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }

  /// Save FCM token to user document using array union
  Future<void> _saveFCMToken(String token) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Use arrayUnion to avoid duplicates and support multiple devices
        await _firestore.collection('users').doc(currentUser.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ FCM Token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '📱 Foreground message received: ${message.notification?.title}',
    );
    debugPrint('📊 Message data: ${message.data}');

    // Show local notification for foreground messages
    _showLocalNotification(message);

    // Handle geofence alerts specifically
    if (message.data['type'] == 'geofence_alert') {
      _handleGeofenceAlert(message.data);
    }
  }

  /// Handle notification that opened the app
  void _handleNotificationOpenedApp(RemoteMessage message) {
    debugPrint(
      '🚀 App opened from notification: ${message.notification?.title}',
    );

    if (message.data['type'] == 'geofence_alert') {
      _handleGeofenceAlert(message.data);
    }
  }

  /// Handle geofence alert data
  void _handleGeofenceAlert(Map<String, dynamic> data) {
    final deviceName = data['deviceName'] ?? 'Unknown Device';
    final geofenceName = data['geofenceName'] ?? 'Unknown Geofence';
    final action = data['action'] ?? 'unknown';

    debugPrint('🎯 Geofence Alert: $deviceName $action $geofenceName');

    // You can add navigation logic here to open specific screens
    // For example, navigate to geofence alerts screen or map view
  }

  /// Handle notification data
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'geofence_alert':
        _handleGeofenceAlert(data);
        break;
      default:
        debugPrint('🔔 Unknown notification type: $type');
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final isGeofenceAlert = data['type'] == 'geofence_alert';

    // Customize notification based on type
    String title = notification.title ?? 'GPS App';
    String body = notification.body ?? '';
    String payload = jsonEncode(data);

    if (isGeofenceAlert) {
      final deviceName = data['deviceName'] ?? 'Vehicle';
      final geofenceName = data['geofenceName'] ?? 'Area';
      final action = data['action'] ?? 'moved';
      final actionText = action == 'enter' ? 'entered' : 'exited';

      title = '🎯 Geofence Alert';
      body = '$deviceName has $actionText $geofenceName';
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'geofence_alerts',
          'Geofence Alerts',
          channelDescription:
              'Notifications for geofence entry and exit events',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF2196F3),
          playSound: true,
          enableVibration: true,
          ticker: 'Geofence Alert',
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
        await _firestore.collection('users').doc(currentUser.uid).update({
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

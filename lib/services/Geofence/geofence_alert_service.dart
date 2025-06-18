import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../../models/Geofence/Geofence.dart';
import '../../services/device/deviceService.dart';

class GeofenceAlertService {
  static final GeofenceAlertService _instance =
      GeofenceAlertService._internal();
  factory GeofenceAlertService() => _instance;
  GeofenceAlertService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceService _deviceService = DeviceService();

  bool _isInitialized = false;
  List<GeofenceAlert> _recentAlerts = [];
  Map<String, StreamSubscription<DatabaseEvent>> _locationListeners = {};
  Map<String, List<Geofence>> _deviceGeofences = {};
  Map<String, Map<String, bool>> _lastGeofenceStatus = {};

  // Initialize the geofence alert service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeFirebaseMessaging();
      await _initializeLocalNotifications();
      await _setupFCMTokenManagement();
      await _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('✅ GeofenceAlertService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ GeofenceAlertService: Initialization failed: $e');
    }
  }

  // Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('FCM Permission status: ${settings.authorizationStatus}');
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for geofence alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_alerts',
      'Geofence Alerts',
      description: 'Notifications for geofence entry and exit events',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.createNotificationChannel(channel);
  }

  // Setup FCM token management
  Future<void> _setupFCMTokenManagement() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM Token saved: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle messages when app is opened from terminated state
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Received foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null && data['type'] == 'geofence_alert') {
      await _showLocalNotification(message);
      await _addToRecentAlerts(message);
    }
  }

  // Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('👆 Notification tapped: ${message.messageId}');

    final data = message.data;
    if (data['type'] == 'geofence_alert') {
      // Navigate to specific geofence or map view
      // This would be handled by the main app navigation
    }
  }

  // Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.id}');
    // Handle local notification tap
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    final String deviceName = data['deviceName'] ?? 'Unknown Device';
    final String geofenceName = data['geofenceName'] ?? 'Unknown Geofence';
    final String action = data['action'] ?? 'unknown';
    final String actionText = action == 'enter' ? 'entered' : 'exited';
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
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      '🚗 Geofence Alert',
      '$deviceName has $actionText $geofenceName',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // Add alert to recent alerts list
  Future<void> _addToRecentAlerts(RemoteMessage message) async {
    final data = message.data;

    final alert = GeofenceAlert(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: data['deviceId'] ?? '',
      deviceName: data['deviceName'] ?? 'Unknown Device',
      geofenceName: data['geofenceName'] ?? 'Unknown Geofence',
      action: data['action'] ?? 'unknown',
      timestamp: DateTime.now(),
      latitude: double.tryParse(data['latitude'] ?? '0') ?? 0,
      longitude: double.tryParse(data['longitude'] ?? '0') ?? 0,
      isRead: false,
    );

    _recentAlerts.insert(0, alert);

    // Keep only last 50 alerts
    if (_recentAlerts.length > 50) {
      _recentAlerts = _recentAlerts.take(50).toList();
    }

    // Save to local storage or Firestore if needed
    await _saveAlertToFirestore(alert);
  }

  // Save alert to Firestore
  Future<void> _saveAlertToFirestore(GeofenceAlert alert) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('user_alerts')
          .doc(user.uid)
          .collection('geofence_alerts')
          .add({
            'deviceId': alert.deviceId,
            'deviceName': alert.deviceName,
            'geofenceName': alert.geofenceName,
            'action': alert.action,
            'timestamp': FieldValue.serverTimestamp(),
            'latitude': alert.latitude,
            'longitude': alert.longitude,
            'isRead': alert.isRead,
          });
    } catch (e) {
      debugPrint('❌ Failed to save alert to Firestore: $e');
    }
  }

  // Get recent alerts
  List<GeofenceAlert> getRecentAlerts() {
    return List.unmodifiable(_recentAlerts);
  }

  // Mark alert as read
  void markAlertAsRead(String alertId) {
    final index = _recentAlerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      _recentAlerts[index] = _recentAlerts[index].copyWith(isRead: true);
    }
  }

  // Clear all alerts
  void clearAllAlerts() {
    _recentAlerts.clear();
  }

  // Get unread alerts count
  int getUnreadAlertsCount() {
    return _recentAlerts.where((alert) => !alert.isRead).length;
  }

  // Test notification (for development)
  Future<void> testNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'geofence_alerts',
          'Geofence Alerts',
          channelDescription: 'Test notification',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '🧪 Test Geofence Alert',
      'Test Vehicle has entered Test Geofence',
      notificationDetails,
    );
  }

  // Dispose resources
  void dispose() {
    // Clean up resources if needed
  }

  // Real-time geofence monitoring methods

  /// Start monitoring location updates for a specific device
  Future<void> startLocationMonitoring(String deviceId) async {
    try {
      // Stop existing monitoring for this device
      await stopLocationMonitoring(deviceId);

      // Get device name (MAC address) for Firebase Realtime Database
      final deviceName = await _deviceService.getDeviceNameById(deviceId);
      if (deviceName == null) {
        debugPrint('❌ GeofenceAlert: Could not get device name for $deviceId');
        return;
      } // Load geofences for this device
      final geofencesSnapshot =
          await _firestore
              .collection('geofences')
              .where('deviceId', isEqualTo: deviceId)
              .where('ownerId', isEqualTo: _auth.currentUser?.uid)
              .get();

      final geofences =
          geofencesSnapshot.docs
              .map((doc) => Geofence.fromMap(doc.data(), doc.id))
              .toList();

      _deviceGeofences[deviceId] = geofences;

      // Initialize geofence status tracking
      _lastGeofenceStatus[deviceId] = {};
      for (final geofence in geofences) {
        _lastGeofenceStatus[deviceId]![geofence.id] = false;
      }

      // Set up Firebase Realtime Database listener
      final ref = FirebaseDatabase.instance.ref('devices/$deviceName/gps');
      final listener = ref.onValue.listen((event) {
        _handleLocationUpdate(deviceId, event);
      });

      _locationListeners[deviceId] = listener;
      debugPrint(
        '✅ GeofenceAlert: Started monitoring device $deviceId ($deviceName)',
      );
    } catch (e) {
      debugPrint('❌ GeofenceAlert: Error starting location monitoring: $e');
    }
  }

  /// Stop monitoring location updates for a specific device
  Future<void> stopLocationMonitoring(String deviceId) async {
    final listener = _locationListeners[deviceId];
    if (listener != null) {
      await listener.cancel();
      _locationListeners.remove(deviceId);
      _deviceGeofences.remove(deviceId);
      _lastGeofenceStatus.remove(deviceId);
      debugPrint('✅ GeofenceAlert: Stopped monitoring device $deviceId');
    }
  }

  /// Stop all location monitoring
  Future<void> stopAllLocationMonitoring() async {
    for (final deviceId in _locationListeners.keys.toList()) {
      await stopLocationMonitoring(deviceId);
    }
  }

  /// Handle location update from Firebase Realtime Database
  void _handleLocationUpdate(String deviceId, DatabaseEvent event) {
    try {
      if (!event.snapshot.exists || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = _parseDouble(data['latitude']);
      final lon = _parseDouble(data['longitude']);

      if (lat == null || lon == null || lat == 0.0 || lon == 0.0) return;

      final currentLocation = LatLng(lat, lon);
      final geofences = _deviceGeofences[deviceId] ?? [];
      final lastStatus = _lastGeofenceStatus[deviceId] ?? {};

      // Check each geofence
      for (final geofence in geofences) {
        if (!geofence.status) continue; // Skip inactive geofences

        final geofencePoints =
            geofence.points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
        final isInside = _isPointInPolygon(currentLocation, geofencePoints);
        final wasInside = lastStatus[geofence.id] ?? false;

        // Detect status change
        if (isInside != wasInside) {
          final action = isInside ? 'enter' : 'exit';
          debugPrint(
            '🚨 GeofenceAlert: Device $deviceId ${action}ed geofence ${geofence.name}',
          );

          // Create and store alert
          _createGeofenceAlert(
            deviceId: deviceId,
            geofence: geofence,
            action: action,
            location: currentLocation,
          );

          // Update status
          _lastGeofenceStatus[deviceId]![geofence.id] = isInside;
        }
      }
    } catch (e) {
      debugPrint('❌ GeofenceAlert: Error handling location update: $e');
    }
  }

  /// Create and process a geofence alert
  Future<void> _createGeofenceAlert({
    required String deviceId,
    required Geofence geofence,
    required String action,
    required LatLng location,
  }) async {
    try {
      // Get device display name
      final device = await _deviceService.getDeviceById(deviceId);
      final deviceDisplayName = device?.name ?? 'Device $deviceId';

      // Create alert object
      final alert = GeofenceAlert(
        id: '${deviceId}_${geofence.id}_${DateTime.now().millisecondsSinceEpoch}',
        deviceId: deviceId,
        deviceName: deviceDisplayName,
        geofenceName: geofence.name,
        action: action,
        timestamp: DateTime.now(),
        latitude: location.latitude,
        longitude: location.longitude,
        isRead: false,
      );

      // Add to recent alerts
      _recentAlerts.insert(0, alert);
      if (_recentAlerts.length > 50) {
        _recentAlerts = _recentAlerts.take(50).toList();
      }

      // Store in Firestore for persistence
      await _storeAlertInFirestore(alert);

      // Show local notification
      await _showGeofenceNotification(alert);
    } catch (e) {
      debugPrint('❌ GeofenceAlert: Error creating alert: $e');
    }
  }

  /// Store alert in Firestore for persistence
  Future<void> _storeAlertInFirestore(GeofenceAlert alert) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('geofence_alerts')
          .doc(alert.id)
          .set(alert.toMap());
    } catch (e) {
      debugPrint('❌ GeofenceAlert: Error storing alert in Firestore: $e');
    }
  }

  /// Show local notification for geofence alert
  Future<void> _showGeofenceNotification(GeofenceAlert alert) async {
    final actionText = alert.action == 'enter' ? 'entered' : 'exited';

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
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      alert.hashCode,
      '🚗 Geofence Alert',
      '${alert.deviceName} has $actionText ${alert.geofenceName}',
      notificationDetails,
      payload: alert.id,
    );
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0, i = 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  /// Parse double value safely from dynamic data
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }
}

// Geofence Alert Model
class GeofenceAlert {
  final String id;
  final String deviceId;
  final String deviceName;
  final String geofenceName;
  final String action; // 'enter' or 'exit'
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final bool isRead;

  const GeofenceAlert({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.geofenceName,
    required this.action,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.isRead,
  });

  String get actionText => action == 'enter' ? 'entered' : 'exited';

  IconData get actionIcon => action == 'enter' ? Icons.login : Icons.logout;

  Color get actionColor => action == 'enter' ? Colors.green : Colors.orange;

  GeofenceAlert copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? geofenceName,
    String? action,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    bool? isRead,
  }) {
    return GeofenceAlert(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      geofenceName: geofenceName ?? this.geofenceName,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'geofenceName': geofenceName,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'isRead': isRead,
    };
  }

  factory GeofenceAlert.fromMap(Map<String, dynamic> map) {
    return GeofenceAlert(
      id: map['id'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      geofenceName: map['geofenceName'] ?? '',
      action: map['action'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      isRead: map['isRead'] ?? false,
    );
  }
}

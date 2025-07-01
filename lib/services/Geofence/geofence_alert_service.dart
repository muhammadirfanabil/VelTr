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

  // Storage for alert deduplication tracking
  final Map<String, Map<String, String>> _lastAlertAction = {}; // deviceId -> {geofenceName: lastAction}
  final Map<String, Map<String, DateTime>> _lastAlertTime = {}; // deviceId -> {geofenceName: lastTime}
  
  // Flag to prevent FCM initialization (set to true when using centralized FCM handling)
  static bool _preventFCMInitialization = false;

  bool _isInitialized = false;
  List<GeofenceAlert> _recentAlerts = [];
  Map<String, StreamSubscription<DatabaseEvent>> _locationListeners = {};
  Map<String, List<Geofence>> _deviceGeofences = {};
  Map<String, Map<String, bool?>> _lastGeofenceStatus = {};

  // Enhanced state tracking with timestamps to prevent rapid transitions
  Map<String, Map<String, DateTime>> _lastTransitionTime = {};
  Map<String, Map<String, String>> _lastAlertId = {};
  Map<String, DateTime> _lastLocationUpdate =
      {}; // Device-level location update tracking

  // Minimum time between transitions for the same geofence (in seconds)
  static const int _minTransitionInterval = 30;

  // Minimum time between location updates processing for the same device (in seconds)
  static const int _minLocationUpdateInterval = 5;

  // Initialize the geofence alert service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // If FCM initialization is prevented, use the FCM-free version
    if (_preventFCMInitialization) {
      debugPrint('⚠️ GeofenceAlertService: FCM initialization prevented, using FCM-free version');
      return await initializeWithoutFCM();
    }
    
    try {
      await _initializeFirebaseMessaging();
      await _initializeLocalNotifications();
      await _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('✅ GeofenceAlertService: Initialized successfully');
    } catch (e) {
      debugPrint('❌ GeofenceAlertService: Initialization failed: $e');
    }
  }

  // Initialize the geofence alert service WITHOUT FCM handlers (to prevent duplicates)
  // This is used when another service (like EnhancedNotificationService) handles FCM
  Future<void> initializeWithoutFCM() async {
    if (_isInitialized) return;
    try {
      // Set the flag to prevent any future FCM initialization
      _preventFCMInitialization = true;
      
      // Only initialize local notifications, skip FCM setup
      await _initializeLocalNotifications();

      _isInitialized = true;
      debugPrint('✅ GeofenceAlertService: Initialized without FCM handlers (preventing duplicates)');
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

  // Add alert to recent alerts list with deduplication
  Future<void> _addToRecentAlerts(RemoteMessage message) async {
    final data = message.data;
    
    final deviceId = data['deviceId'] ?? '';
    final geofenceName = data['geofenceName'] ?? 'Unknown Geofence';
    final action = data['action'] ?? 'unknown';
    
    // Check for duplicate - skip if same device+geofence had same action recently
    if (_isDuplicateAlert(deviceId, geofenceName, action)) {
      debugPrint('🔄 Skipping duplicate alert: $deviceId @ $geofenceName ($action)');
      return; // Re-enabled deduplication
    }
    
    // Update the last action for this device+geofence
    _updateLastAlertAction(deviceId, geofenceName, action);

    final alert = GeofenceAlert(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: deviceId,
      deviceName: data['deviceName'] ?? 'Unknown Device',
      geofenceName: geofenceName,
      action: action,
      timestamp: DateTime.now(),
      latitude: double.tryParse(data['latitude'] ?? '0') ?? 0,
      longitude: double.tryParse(data['longitude'] ?? '0') ?? 0,
      isRead: false,
    );

    _recentAlerts.insert(0, alert);
    debugPrint('✅ Added alert: $deviceId @ $geofenceName ($action)');

    // Keep only last 50 alerts
    if (_recentAlerts.length > 50) {
      _recentAlerts = _recentAlerts.take(50).toList();
    }

    // Notify UI listeners
    _notifyAlertsUpdated();

    // Save to local storage or Firestore if needed
    await _saveAlertToFirestore(alert);

    // Notify listeners about the updated alerts (removed redundant call)
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

  // Check if this alert is a duplicate (same device+geofence+action as last time within short period)
  bool _isDuplicateAlert(String deviceId, String geofenceName, String action) {
    final deviceAlerts = _lastAlertAction[deviceId];
    final deviceTimes = _lastAlertTime[deviceId];
    
    if (deviceAlerts == null || deviceTimes == null) return false;
    
    final lastAction = deviceAlerts[geofenceName];
    final lastTime = deviceTimes[geofenceName];
    
    // Only consider it a duplicate if:
    // 1. Same action as last time AND
    // 2. Within 60 seconds of the last alert
    if (lastAction == action && lastTime != null) {
      final timeDifference = DateTime.now().difference(lastTime).inSeconds;
      if (timeDifference < 60) {
        debugPrint('⏰ Duplicate detected: Same action within ${timeDifference}s');
        return true;
      }
    }
    
    return false;
  }

  // Update the last alert action and time for device+geofence combination
  void _updateLastAlertAction(String deviceId, String geofenceName, String action) {
    _lastAlertAction[deviceId] ??= {};
    _lastAlertTime[deviceId] ??= {};
    
    _lastAlertAction[deviceId]![geofenceName] = action;
    _lastAlertTime[deviceId]![geofenceName] = DateTime.now();
  }

  // Stream controller for reactive UI updates
  final StreamController<List<GeofenceAlert>> _alertsStreamController = StreamController<List<GeofenceAlert>>.broadcast();

  // Get recent alerts as a stream for reactive UI updates
  Stream<List<GeofenceAlert>> getRecentAlertsStream() {
    return _alertsStreamController.stream;
  }

  // Notify listeners when alerts are updated
  void _notifyAlertsUpdated() {
    if (!_alertsStreamController.isClosed) {
      _alertsStreamController.add(List.unmodifiable(_recentAlerts));
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
    _lastAlertAction.clear();
    _lastAlertTime.clear();
    debugPrint('🧹 Cleared all alerts and deduplication state');
    _notifyAlertsUpdated();
  }

  // Clear alert state for a specific device (useful when device is removed)
  void clearDeviceAlertState(String deviceId) {
    _lastAlertAction.remove(deviceId);
    _lastAlertTime.remove(deviceId);
    debugPrint('🧹 Cleared alert state for device: $deviceId');
  }

  /// Get current monitoring status for debugging
  Map<String, dynamic> getMonitoringStatus() {
    return {
      'totalDevices': _locationListeners.length,
      'activeDevices': _locationListeners.keys.toList(),
      'totalGeofences':
          _deviceGeofences.values.expand((geofences) => geofences).length,
      'deviceGeofenceCounts': _deviceGeofences.map(
        (deviceId, geofences) => MapEntry(deviceId, geofences.length),
      ),
      'recentAlertsCount': _recentAlerts.length,
      'deduplicationState': _lastAlertAction,
      'lastAlertTimes': _lastAlertTime,
      'fcmInitializationPrevented': _preventFCMInitialization,
    };
  }

  /// Get current geofence states for a device (for debugging)
  Map<String, bool?>? getDeviceGeofenceStates(String deviceId) {
    return _lastGeofenceStatus[deviceId];
  }

  /// Get last transition times for a device (for debugging)
  Map<String, DateTime>? getDeviceTransitionTimes(String deviceId) {
    return _lastTransitionTime[deviceId];
  }

  /// Force refresh geofence states for a device
  Future<void> refreshDeviceGeofences(String deviceId) async {
    debugPrint('🔄 GeofenceAlert: Refreshing geofences for device $deviceId');

    // Stop current monitoring
    await stopLocationMonitoring(deviceId);

    // Restart monitoring to reload geofences
    await startLocationMonitoring(deviceId);
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
    // Close the stream controller
    _alertsStreamController.close();
    
    // Clean up location listeners
    for (final subscription in _locationListeners.values) {
      subscription.cancel();
    }
    _locationListeners.clear();
    
    debugPrint('🧹 GeofenceAlertService disposed');
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

      // Initialize geofence status tracking with enhanced state management
      _lastGeofenceStatus[deviceId] = {};
      _lastTransitionTime[deviceId] = {};
      _lastAlertId[deviceId] = {};

      // Initialize with null state - will be determined on first location update
      for (final geofence in geofences) {
        _lastGeofenceStatus[deviceId]![geofence.id] =
            null; // null = unknown state
        _lastTransitionTime[deviceId]![geofence.id] = DateTime.now().subtract(
          Duration(seconds: _minTransitionInterval + 1),
        ); // Initialize to allow immediate first transition
        _lastAlertId[deviceId]![geofence.id] = '';
      }

      debugPrint(
        '📊 GeofenceAlert: Initialized tracking for ${geofences.length} geofences on device $deviceId',
      );

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
      _lastTransitionTime.remove(deviceId);
      _lastAlertId.remove(deviceId);
      _lastLocationUpdate.remove(deviceId);
      _lastAlertAction.remove(deviceId); // Also clean up alert deduplication state
      _lastAlertTime.remove(deviceId); // Also clean up time tracking
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
  void _handleLocationUpdate(String deviceId, DatabaseEvent event) async {
    try {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        debugPrint('⚠️ GeofenceAlert: No location data for device $deviceId');
        return;
      }

      // Device-level debouncing to prevent rapid processing
      final now = DateTime.now();
      final lastUpdate = _lastLocationUpdate[deviceId];
      if (lastUpdate != null) {
        final timeSinceLastUpdate = now.difference(lastUpdate).inSeconds;
        if (timeSinceLastUpdate < _minLocationUpdateInterval) {
          debugPrint(
            '⏱️ GeofenceAlert: Location update too frequent for device $deviceId (${timeSinceLastUpdate}s < ${_minLocationUpdateInterval}s) - skipping',
          );
          return;
        }
      }
      _lastLocationUpdate[deviceId] = now;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final lat = _parseDouble(data['latitude']);
      final lon = _parseDouble(data['longitude']);

      if (lat == null || lon == null || lat == 0.0 || lon == 0.0) {
        debugPrint(
          '⚠️ GeofenceAlert: Invalid coordinates for device $deviceId: lat=$lat, lon=$lon',
        );
        return;
      }

      final currentLocation = LatLng(lat, lon);
      final geofences = _deviceGeofences[deviceId] ?? [];
      final lastStatus = _lastGeofenceStatus[deviceId] ?? {};
      final lastTransitionTimes = _lastTransitionTime[deviceId] ?? {};

      debugPrint(
        '📍 GeofenceAlert: Processing location update for device $deviceId at ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
      );

      // Check each geofence
      for (final geofence in geofences) {
        if (!geofence.status) {
          debugPrint(
            '⏭️ GeofenceAlert: Skipping inactive geofence ${geofence.name}',
          );
          continue;
        }

        final geofencePoints =
            geofence.points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();

        if (geofencePoints.length < 3) {
          debugPrint(
            '⚠️ GeofenceAlert: Geofence ${geofence.name} has insufficient points (${geofencePoints.length})',
          );
          continue;
        }

        final isInside = _isPointInPolygon(currentLocation, geofencePoints);
        final wasInside =
            lastStatus[geofence.id]; // Can be null, true, or false
        final lastTransition =
            lastTransitionTimes[geofence.id] ??
            DateTime.now().subtract(Duration(days: 1));
        final now = DateTime.now();

        debugPrint(
          '🔍 GeofenceAlert: Geofence ${geofence.name} - wasInside: $wasInside, isInside: $isInside',
        );

        // If this is the first location update (wasInside is null), just initialize the state
        if (wasInside == null) {
          _lastGeofenceStatus[deviceId]![geofence.id] = isInside;
          _lastTransitionTime[deviceId]![geofence.id] = now;
          debugPrint(
            '🆕 GeofenceAlert: Initialized state for ${geofence.name} - isInside: $isInside',
          );
          continue;
        }

        // Detect status change with debouncing (only if state has actually changed)
        if (isInside != wasInside) {
          final timeSinceLastTransition =
              now.difference(lastTransition).inSeconds;

          if (timeSinceLastTransition < _minTransitionInterval) {
            debugPrint(
              '⏱️ GeofenceAlert: Transition too recent for ${geofence.name} (${timeSinceLastTransition}s < ${_minTransitionInterval}s) - ignoring',
            );
            continue;
          }

          final action = isInside ? 'enter' : 'exit';
          debugPrint(
            '🚨 GeofenceAlert: Device $deviceId ${action}ed geofence ${geofence.name} (transition after ${timeSinceLastTransition}s)',
          );

          // Update status and transition time BEFORE creating alert to prevent duplicates
          _lastGeofenceStatus[deviceId]![geofence.id] = isInside;
          _lastTransitionTime[deviceId]![geofence.id] = now;

          // Create and store alert
          final alertId = await _createGeofenceAlert(
            deviceId: deviceId,
            geofence: geofence,
            action: action,
            location: currentLocation,
          );

          if (alertId != null) {
            _lastAlertId[deviceId]![geofence.id] = alertId;
            debugPrint(
              '✅ GeofenceAlert: Successfully processed $action event for ${geofence.name}',
            );
          } else {
            debugPrint(
              '❌ GeofenceAlert: Failed to create alert for ${geofence.name}',
            );
          }
        } else {
          // No status change - log for debugging
          final statusText = isInside ? 'inside' : 'outside';
          debugPrint(
            '➡️ GeofenceAlert: Device $deviceId remains $statusText geofence ${geofence.name}',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '❌ GeofenceAlert: Error handling location update for device $deviceId: $e',
      );
    }
  }

  /// Create and process a geofence alert
  Future<String?> _createGeofenceAlert({
    required String deviceId,
    required Geofence geofence,
    required String action,
    required LatLng location,
  }) async {
    try {
      // Get device display name
      final device = await _deviceService.getDeviceById(deviceId);
      final deviceDisplayName = device?.name ?? 'Device $deviceId';

      // Create alert object with unique ID
      final alertId =
          '${deviceId}_${geofence.id}_${DateTime.now().millisecondsSinceEpoch}';
      final alert = GeofenceAlert(
        id: alertId,
        deviceId: deviceId,
        deviceName: deviceDisplayName,
        geofenceName: geofence.name,
        action: action,
        timestamp: DateTime.now(),
        latitude: location.latitude,
        longitude: location.longitude,
        isRead: false,
      );

      debugPrint(
        '📝 GeofenceAlert: Creating alert - ${alert.deviceName} ${alert.actionText} ${alert.geofenceName}',
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

      debugPrint(
        '✅ GeofenceAlert: Successfully created and processed alert $alertId',
      );
      return alertId;
    } catch (e) {
      debugPrint('❌ GeofenceAlert: Error creating alert: $e');
      return null;
    }
  }

  /// Store alert in Firestore for persistence
  Future<void> _storeAlertInFirestore(GeofenceAlert alert) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore
          .collection('users_information')
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
    final actionEmoji = alert.action == 'enter' ? '📍' : '🚪';
    final timeText = _formatTime(alert.timestamp);

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
          // Add action buttons for quick response
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'mark_read',
              'Mark as Read',
              icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
            ),
            AndroidNotificationAction(
              'view_map',
              'View on Map',
              icon: DrawableResourceAndroidBitmap('@drawable/ic_map'),
            ),
          ],
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Enhanced notification content with more details
    final title = '$actionEmoji Geofence Alert';
    final body =
        '${alert.deviceName} has $actionText ${alert.geofenceName} at $timeText';

    await _localNotifications.show(
      alert.hashCode,
      title,
      body,
      notificationDetails,
      payload: alert.id,
    );

    debugPrint('📳 GeofenceAlert: Notification sent - $title: $body');
  }

  /// Format timestamp for notification
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
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

  // Public method to handle FCM messages (called by EnhancedNotificationService)
  Future<void> handleFCMMessage(RemoteMessage message) async {
    debugPrint('🎯 GeofenceAlertService: Handling FCM message ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'geofence_alert') {
      // Show local notification
      await _showLocalNotification(message);
      // Add to recent alerts
      await _addToRecentAlerts(message);
    }
  }

  // Public method to handle notification taps (called by EnhancedNotificationService)  
  void handleNotificationTap(RemoteMessage message) {
    debugPrint('🎯 GeofenceAlertService: Handling notification tap ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'geofence_alert') {
      // Navigate to specific geofence or map view
      // This would be handled by the main app navigation
      debugPrint('🗺️ Should navigate to geofence: ${data['geofenceName']}');
    }
  }

  // Debug method to test alert addition manually
  Future<void> debugAddTestAlert() async {
    debugPrint('🧪 Adding test alert for debugging...');
    
    // Directly create a test alert
    final alert = GeofenceAlert(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: 'test_device_001',
      deviceName: 'Test Device',
      geofenceName: 'Test Geofence',
      action: 'enter',
      timestamp: DateTime.now(),
      latitude: -6.2088,
      longitude: 106.8456,
      isRead: false,
    );
    
    _recentAlerts.insert(0, alert);
    debugPrint('🧪 Test alert added. Current alerts count: ${_recentAlerts.length}');
    
    // Keep only last 50 alerts
    if (_recentAlerts.length > 50) {
      _recentAlerts = _recentAlerts.take(50).toList();
    }
    
    // Notify UI listeners
    _notifyAlertsUpdated();
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

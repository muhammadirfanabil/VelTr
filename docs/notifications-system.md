# Notifications System Documentation

## Overview

The Notifications System provides comprehensive alert management for the GPS tracking application, handling geofence violations, device status changes, system alerts, and user notifications. It features a unified notification model with intelligent grouping, real-time delivery, and enhanced user experience.

## Code Structure

### Core Files

#### Screens

- `lib/screens/notifications/enhanced_notifications_screen.dart` - Main unified notification interface
- `lib/screens/notifications/notification_settings.dart` - User notification preferences
- `lib/screens/notifications/notification_details.dart` - Detailed notification view

#### Services

- `lib/services/notifications/enhanced_notification_service.dart` - Core notification processing
- `lib/services/notifications/fcm_service.dart` - Firebase Cloud Messaging integration
- `lib/services/notifications/notification_manager.dart` - Local notification management

#### Models

- `lib/models/notifications/unified_notification.dart` - Unified notification data model
- `lib/models/notifications/notification_settings.dart` - User preference model

#### Widgets

- `lib/widgets/notifications/notification_card.dart` - Individual notification display card
- `lib/widgets/notifications/notification_group.dart` - Grouped notification display
- `lib/widgets/notifications/notification_badge.dart` - Notification count indicators

## Data Flow

### 1. Notification Generation Flow

1. **Event Detection**: System detects triggering events (geofence violation, device status change)
2. **Rule Processing**: Event processed against user notification rules and preferences
3. **Notification Creation**: UnifiedNotification object created with relevant metadata
4. **Delivery**: Notification sent via Firebase Cloud Messaging (FCM)
5. **Local Storage**: Notification stored locally for history and offline access
6. **UI Update**: Real-time UI updates with new notification

### 2. Geofence Alert Flow

1. **Boundary Detection**: Device location monitored against active geofences
2. **Enter/Exit Events**: Boundary violations detected and classified
3. **Alert Generation**: Geofence alert created with device and location context
4. **User Notification**: Push notification sent to user's device
5. **In-App Display**: Alert appears in notification list with proper categorization
6. **Status Tracking**: Alert marked as read/unread, archived, etc.

### 3. Real-time Notification Flow

1. **FCM Integration**: Firebase Cloud Messaging receives server-side events
2. **Background Processing**: App processes notifications even when backgrounded
3. **Local Database**: Notifications stored in local SQLite database
4. **UI Synchronization**: Active UI synchronized with new notifications
5. **Badge Updates**: App icon badge updated with unread count

## API/Service Reference

### Enhanced Notification Service Methods

```dart
// Get all notifications with filtering
Future<List<UnifiedNotification>> getAllNotifications({
  NotificationType? type,
  DateTime? startDate,
  DateTime? endDate,
  bool? isRead
})

// Mark notification as read
Future<void> markAsRead(String notificationId)

// Mark all notifications as read
Future<void> markAllAsRead()

// Delete notification
Future<void> deleteNotification(String notificationId)

// Clear all notifications
Future<void> clearAllNotifications()

// Get unread count
Future<int> getUnreadCount()
```

### FCM Service Methods

```dart
// Initialize FCM
Future<void> initialize()

// Get FCM token
Future<String?> getToken()

// Handle foreground messages
void handleForegroundMessage(RemoteMessage message)

// Handle background messages
void handleBackgroundMessage(RemoteMessage message)

// Subscribe to topic
Future<void> subscribeToTopic(String topic)
```

### Unified Notification Data Structure

```dart
{
  'id': String,                    // Unique notification identifier
  'type': NotificationType,        // GEOFENCE_ALERT, DEVICE_STATUS, SYSTEM
  'title': String,                 // Notification title
  'message': String,               // Notification content
  'timestamp': DateTime,           // Creation timestamp
  'isRead': bool,                  // Read status
  'priority': Priority,            // HIGH, MEDIUM, LOW
  'deviceId': String?,             // Associated device ID
  'vehicleId': String?,            // Associated vehicle ID
  'geofenceId': String?,           // Associated geofence ID
  'data': Map<String, dynamic>?,   // Additional metadata
  'actions': List<NotificationAction>? // Available actions
}
```

## UI Behavior

### Enhanced Notifications Screen

- **Date Grouping**: Notifications grouped by date (Today, Yesterday, This Week, etc.)
- **Visual Hierarchy**: Clear visual distinction between notification types
- **Status Indicators**: Color-coded indicators for different alert types
- **Interactive Cards**: Swipe-to-delete, tap for details, long-press for actions
- **Search/Filter**: Real-time search and filtering by type, date, status

### Notification Cards

- **Geofence Alerts**: Green for entry, red for exit, with location context
- **Device Status**: Battery, connection, and operational status updates
- **System Alerts**: App updates, maintenance, and system notifications
- **Time Display**: Intelligent relative time (Just now, 5 mins ago, etc.)

### Notification Settings

- **Type Preferences**: Enable/disable different notification types
- **Delivery Methods**: Push, in-app, email preferences
- **Quiet Hours**: Do-not-disturb scheduling
- **Geofence Settings**: Per-geofence notification preferences

### Real-time Features

- **Live Updates**: Notifications appear instantly without refresh
- **Badge Indicators**: Unread count badges throughout the app
- **Sound/Vibration**: Customizable alert sounds and vibration patterns

## Technical Implementation Details

### Notification Categorization

```dart
enum NotificationType {
  GEOFENCE_ALERT,    // Geofence enter/exit events
  DEVICE_STATUS,     // Device online/offline, battery, etc.
  SYSTEM_ALERT,      // App updates, maintenance
  USER_MESSAGE,      // Direct user communications
  SECURITY_ALERT     // Security-related notifications
}
```

### Message Formatting

- **Geofence Alerts**: "[VehicleName] has entered/exited [GeofenceName]"
- **Device Status**: "[DeviceName] is now online/offline"
- **System Alerts**: "System maintenance scheduled for [Date]"

### Data Persistence

- **Local Storage**: SQLite database for offline notification access
- **Cloud Sync**: Firebase Firestore for cross-device synchronization
- **Retention Policy**: Configurable notification retention periods
- **Data Compression**: Efficient storage of notification metadata

### Performance Optimization

- **Lazy Loading**: On-demand loading of notification history
- **Background Processing**: Efficient background notification handling
- **Memory Management**: Proper cleanup of notification resources
- **Network Optimization**: Minimal bandwidth usage for notifications

## Developer Notes

### FCM Integration Setup

- **Firebase Configuration**: Proper FCM setup with iOS and Android certificates
- **Token Management**: FCM token refresh and synchronization
- **Message Handling**: Foreground and background message processing
- **Topic Subscriptions**: User-based and group-based topic management

### Local Database Schema

```sql
CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  is_read INTEGER DEFAULT 0,
  priority INTEGER DEFAULT 1,
  device_id TEXT,
  vehicle_id TEXT,
  geofence_id TEXT,
  data TEXT,
  created_at INTEGER DEFAULT CURRENT_TIMESTAMP
);
```

### Security Considerations

- **Data Privacy**: Encrypted storage of sensitive notification data
- **Access Control**: User-based notification access permissions
- **Message Validation**: Server-side validation of notification content
- **Rate Limiting**: Protection against notification spam

### Recent Improvements

#### Enhanced Notification System (Latest)

- **Unified Model**: Single notification model for all alert types
- **Improved UI**: Modern card design with better visual hierarchy
- **Date Grouping**: Intelligent date-based notification grouping
- **Swipe Actions**: Enhanced user interaction with swipe-to-delete
- **Real-time Updates**: Live notification updates without refresh

#### FCM Integration Enhancement

- **Background Processing**: Improved background notification handling
- **Token Management**: Better FCM token lifecycle management
- **Message Formatting**: Standardized notification message formats
- **Error Handling**: Comprehensive error handling and recovery

#### Performance Improvements

- **Memory Optimization**: Reduced memory footprint for notification processing
- **Database Efficiency**: Optimized local notification storage
- **Network Usage**: Minimized data usage for notification sync

### Testing Guidelines

- **Push Notification Testing**: Test FCM delivery across different app states
- **Background Testing**: Verify background notification processing
- **Edge Cases**: Test with poor network, app backgrounded, device offline
- **Performance**: Monitor with high notification volume
- **Cross-platform**: Ensure consistent behavior on Android and iOS

### Integration Points

- **Geofence System**: Geofence violations generate notifications
- **Device Management**: Device status changes trigger alerts
- **User Settings**: User preferences control notification behavior
- **Analytics**: Notification engagement tracked for insights

## Future Enhancements

### Planned Features

- **Rich Notifications**: Images, actions, and interactive elements
- **Notification Channels**: Android notification channel management
- **Smart Grouping**: AI-powered notification grouping and prioritization
- **Custom Actions**: User-defined notification response actions
- **Analytics Dashboard**: Notification engagement and effectiveness metrics

### Technical Improvements

- **Machine Learning**: Intelligent notification filtering and prioritization
- **Real-time Analytics**: Live notification performance monitoring
- **A/B Testing**: Notification content and timing optimization
- **Advanced Personalization**: AI-driven notification customization

### Technical Debt

- **Code Consolidation**: Further consolidation of notification utilities
- **Testing Coverage**: Comprehensive automated testing for notifications
- **Documentation**: Complete API documentation for notification services
- **Performance**: Optimization for high-volume notification scenarios

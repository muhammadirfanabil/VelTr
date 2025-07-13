import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Enumeration for notification types
enum NotificationType {
  geofence,
  general,
  system,
  vehicleStatus;

  String get displayName {
    switch (this) {
      case NotificationType.geofence:
        return 'Geofence Alert';
      case NotificationType.general:
        return 'General';
      case NotificationType.system:
        return 'System';
      case NotificationType.vehicleStatus:
        return 'Vehicle Status';
    }
  }
}

/// Enumeration for geofence actions
enum GeofenceAction {
  enter,
  exit,
  unknown;

  String get displayName {
    switch (this) {
      case GeofenceAction.enter:
        return 'entered';
      case GeofenceAction.exit:
        return 'exited';
      case GeofenceAction.unknown:
        return 'moved';
    }
  }

  String get badgeText {
    switch (this) {
      case GeofenceAction.enter:
        return 'ENTERED';
      case GeofenceAction.exit:
        return 'EXITED';
      case GeofenceAction.unknown:
        return 'UNKNOWN';
    }
  }

  IconData get icon {
    switch (this) {
      case GeofenceAction.enter:
        return Icons.login_rounded;
      case GeofenceAction.exit:
        return Icons.logout_rounded;
      case GeofenceAction.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GeofenceAction.enter:
        return AppColors.success;
      case GeofenceAction.exit:
        return AppColors.error;
      case GeofenceAction.unknown:
        return AppColors.textSecondary;
    }
  }

  Color get badgeColor {
    switch (this) {
      case GeofenceAction.enter:
        return AppColors.successLight;
      case GeofenceAction.exit:
        return AppColors.errorLight;
      case GeofenceAction.unknown:
        return AppColors.backgroundTertiary;
    }
  }

  Color get badgeTextColor {
    switch (this) {
      case GeofenceAction.enter:
        return AppColors.successText;
      case GeofenceAction.exit:
        return AppColors.errorText;
      case GeofenceAction.unknown:
        return AppColors.textDisabled;
    }
  }

  static GeofenceAction fromString(String? action) {
    switch (action?.toLowerCase()) {
      case 'enter':
        return GeofenceAction.enter;
      case 'exit':
        return GeofenceAction.exit;
      default:
        return GeofenceAction.unknown;
    }
  }
}

/// Unified notification model to combine all notification types
class UnifiedNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isRead;
  final GeofenceAction? geofenceAction;
  final String? deviceName;
  final String? geofenceName;
  final double? latitude;
  final double? longitude;

  const UnifiedNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.data,
    this.isRead = false,
    this.geofenceAction,
    this.deviceName,
    this.geofenceName,
    this.latitude,
    this.longitude,
  });

  /// Factory constructor for creating from Firestore data
  factory UnifiedNotification.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    required NotificationType type,
  }) {
    DateTime timestamp;

    // Handle different timestamp field names
    if (data['timestamp'] != null) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['waktu'] != null) {
      timestamp = (data['waktu'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    if (type == NotificationType.geofence) {
      return UnifiedNotification._fromGeofenceData(
        id: id,
        data: data,
        timestamp: timestamp,
      );
    } else if (type == NotificationType.vehicleStatus) {
      return UnifiedNotification._fromVehicleStatusData(
        id: id,
        data: data,
        timestamp: timestamp,
      );
    } else {
      return UnifiedNotification._fromGeneralData(
        id: id,
        data: data,
        timestamp: timestamp,
      );
    }
  }

  /// Factory for geofence notifications
  factory UnifiedNotification._fromGeofenceData({
    required String id,
    required Map<String, dynamic> data,
    required DateTime timestamp,
  }) {
    final deviceName = data['deviceName'] ?? 'Unknown Device';
    final geofenceName = data['geofenceName'] ?? 'Unknown Geofence';
    final action = GeofenceAction.fromString(data['action']);

    return UnifiedNotification(
      id: id,
      type: NotificationType.geofence,
      title: geofenceName,
      message: '$deviceName has ${action.displayName} $geofenceName',
      timestamp: timestamp,
      data: data,
      isRead: data['isRead'] ?? data['read'] ?? false,
      geofenceAction: action,
      deviceName: deviceName,
      geofenceName: geofenceName,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
    );
  }

  /// Factory for general notifications
  factory UnifiedNotification._fromGeneralData({
    required String id,
    required Map<String, dynamic> data,
    required DateTime timestamp,
  }) {
    final geofenceName = data['geofenceName'] ?? 'Notification';
    final status = data['status'] ?? '';

    String message = status;
    if (status == 'Masuk area' || status.toLowerCase().contains('enter')) {
      message = 'Vehicle has entered $geofenceName';
    } else if (status.toLowerCase().contains('exit')) {
      message = 'Vehicle has exited $geofenceName';
    }

    return UnifiedNotification(
      id: id,
      type: NotificationType.general,
      title: geofenceName,
      message: message.isNotEmpty ? message : 'General notification',
      timestamp: timestamp,
      data: data,
      isRead: data['read'] ?? false,
      latitude: data['location']?['lat']?.toDouble(),
      longitude: data['location']?['lng']?.toDouble(),
    );
  }

  /// Factory for vehicle status notifications
  factory UnifiedNotification._fromVehicleStatusData({
    required String id,
    required Map<String, dynamic> data,
    required DateTime timestamp,
  }) {
    final vehicleName =
        data['vehicleName'] ?? data['deviceName'] ?? 'Unknown Vehicle';
    final deviceName = data['deviceName'] ?? 'Unknown Device';
    final actionText = data['actionText'] ?? '';
    final relayStatus =
        data['relayStatus'] == 'true' || data['relayStatus'] == true;

    // Use the message from the backend or construct it
    final message =
        data['message'] ?? '✅ $vehicleName has been successfully $actionText.';

    return UnifiedNotification(
      id: id,
      type: NotificationType.vehicleStatus,
      title: 'Vehicle Status Update',
      message: message,
      timestamp: timestamp,
      data: data,
      isRead: data['isRead'] ?? data['read'] ?? false,
      deviceName: deviceName, // Use actual device name for filtering
      geofenceName: 'Status: ${relayStatus ? 'ON' : 'OFF'}',
    );
  }

  /// Helper method to get vehicle relay status from notification data
  bool _getVehicleRelayStatus() {
    if (type == NotificationType.vehicleStatus) {
      final relayStatus = data['relayStatus'];
      if (relayStatus is bool) {
        return relayStatus;
      } else if (relayStatus is String) {
        return relayStatus.toLowerCase() == 'true';
      }
    }
    return false; // Default to OFF if status cannot be determined
  }

  /// Get display icon based on notification type
  IconData get icon {
    if (type == NotificationType.geofence && geofenceAction != null) {
      return geofenceAction!.icon;
    } else if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? Icons.power_rounded : Icons.power_off_rounded;
    }
    return Icons.notifications_rounded;
  }

  /// Get color based on notification type
  Color get color {
    if (type == NotificationType.geofence && geofenceAction != null) {
      return geofenceAction!.color;
    } else if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? AppColors.success : AppColors.error;
    }
    return AppColors.info;
  }

  /// Get badge text for display
  String get badgeText {
    if (type == NotificationType.geofence && geofenceAction != null) {
      return geofenceAction!.badgeText;
    } else if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? 'ON' : 'OFF';
    }
    return type.displayName.toUpperCase();
  }

  /// Get badge background color
  Color get badgeColor {
    if (type == NotificationType.geofence && geofenceAction != null) {
      return geofenceAction!.badgeColor;
    } else if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? AppColors.successLight : AppColors.errorLight;
    }
    return AppColors.infoLight;
  }

  /// Get badge text color
  Color get badgeTextColor {
    if (type == NotificationType.geofence && geofenceAction != null) {
      return geofenceAction!.badgeTextColor;
    } else if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? AppColors.successText : AppColors.errorText;
    }
    return AppColors.infoText;
  }

  /// Get border color for vehicle status notifications
  Color? get borderColor {
    if (type == NotificationType.vehicleStatus) {
      final relayStatus = _getVehicleRelayStatus();
      return relayStatus ? AppColors.success : AppColors.error;
    }
    return null; // No border for other notification types
  }

  /// Check if notification has location data
  bool get hasLocation => latitude != null && longitude != null;

  /// Get formatted location string
  String? get formattedLocation {
    if (!hasLocation) return null;
    return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'isRead': isRead,
      'geofenceAction': geofenceAction?.name,
      'deviceName': deviceName,
      'geofenceName': geofenceName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create copy with modified fields
  UnifiedNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    bool? isRead,
    GeofenceAction? geofenceAction,
    String? deviceName,
    String? geofenceName,
    double? latitude,
    double? longitude,
  }) {
    return UnifiedNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      geofenceAction: geofenceAction ?? this.geofenceAction,
      deviceName: deviceName ?? this.deviceName,
      geofenceName: geofenceName ?? this.geofenceName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UnifiedNotification(id: $id, type: $type, title: $title, timestamp: $timestamp)';
  }
}

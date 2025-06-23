import 'package:flutter/material.dart';

/// Centralized icon definitions for the GPS app
/// All icons used throughout the app should be defined here for consistency
class AppIcons {
  // Private constructor to prevent instantiation
  AppIcons._();

  // ============================================================================
  // NAVIGATION & SYSTEM ICONS
  // ============================================================================

  static const IconData home = Icons.home;
  static const IconData map = Icons.map;
  static const IconData notifications = Icons.notifications;
  static const IconData settings = Icons.settings;
  static const IconData menu = Icons.menu;
  static const IconData back = Icons.arrow_back;
  static const IconData close = Icons.close;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list;
  static const IconData refresh = Icons.refresh;
  static const IconData more = Icons.more_vert;

  // ============================================================================
  // DEVICE & VEHICLE ICONS
  // ============================================================================

  static const IconData device = Icons.devices;
  static const IconData vehicle = Icons.directions_car;
  static const IconData motorcycle = Icons.motorcycle;
  static const IconData truck = Icons.local_shipping;
  static const IconData gps = Icons.gps_fixed;
  static const IconData gpsOff = Icons.gps_off;
  static const IconData batteryFull = Icons.battery_full;
  static const IconData batteryHalf = Icons.battery_std;
  static const IconData batteryLow = Icons.battery_alert;
  static const IconData batteryEmpty = Icons.battery_0_bar;
  static const IconData signal = Icons.signal_cellular_4_bar;
  static const IconData signalWeak = Icons.signal_cellular_alt;
  static const IconData signalOff = Icons.signal_cellular_off;

  // ============================================================================
  // MAP & LOCATION ICONS
  // ============================================================================

  static const IconData location = Icons.location_on;
  static const IconData locationOff = Icons.location_off;
  static const IconData myLocation = Icons.my_location;
  static const IconData directions = Icons.directions;
  static const IconData route = Icons.route;
  static const IconData mapMarker = Icons.place;
  static const IconData geofence = Icons.location_city;
  static const IconData geofenceAdd = Icons.add_location;
  static const IconData geofenceEdit = Icons.edit_location;
  static const IconData geofenceDelete = Icons.delete_forever;
  static const IconData centerFocus = Icons.center_focus_strong;
  static const IconData zoom = Icons.zoom_in_map;

  // ============================================================================
  // NOTIFICATION ICONS
  // ============================================================================

  static const IconData notificationBell = Icons.notifications;
  static const IconData notificationAlert = Icons.notification_important;
  static const IconData notificationClear = Icons.clear_all;
  static const IconData notificationRead = Icons.mark_email_read;
  static const IconData notificationUnread = Icons.mark_email_unread;
  static const IconData warning = Icons.warning;
  static const IconData error = Icons.error;
  static const IconData info = Icons.info;
  static const IconData success = Icons.check_circle;

  // ============================================================================
  // ACTION ICONS
  // ============================================================================

  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData save = Icons.save;
  static const IconData cancel = Icons.cancel;
  static const IconData confirm = Icons.check;
  static const IconData copy = Icons.copy;
  static const IconData share = Icons.share;
  static const IconData download = Icons.download;
  static const IconData upload = Icons.upload;
  static const IconData sync = Icons.sync;
  static const IconData visibility = Icons.visibility;
  static const IconData visibilityOff = Icons.visibility_off;

  // ============================================================================
  // STATUS ICONS
  // ============================================================================

  static const IconData online = Icons.circle;
  static const IconData offline = Icons.circle_outlined;
  static const IconData active = Icons.play_circle_filled;
  static const IconData inactive = Icons.pause_circle_filled;
  static const IconData connected = Icons.link;
  static const IconData disconnected = Icons.link_off;
  static const IconData loading = Icons.hourglass_empty;
  static const IconData done = Icons.done;
  static const IconData pending = Icons.pending;

  // ============================================================================
  // TIME & HISTORY ICONS
  // ============================================================================

  static const IconData history = Icons.history;
  static const IconData time = Icons.access_time;
  static const IconData calendar = Icons.calendar_today;
  static const IconData dateRange = Icons.date_range;
  static const IconData schedule = Icons.schedule;
  static const IconData timeline = Icons.timeline;

  // ============================================================================
  // USER & ACCOUNT ICONS
  // ============================================================================

  static const IconData user = Icons.person;
  static const IconData userCircle = Icons.account_circle;
  static const IconData users = Icons.group;
  static const IconData login = Icons.login;
  static const IconData logout = Icons.logout;
  static const IconData security = Icons.security;
  static const IconData key = Icons.key;

  // ============================================================================
  // CUSTOM ASSET ICONS
  // ============================================================================

  /// Custom app icon paths
  static const String appIconSvg = 'assets/icons/appicon1.svg';
  static const String appIconBlack = 'assets/icons/appiconblk.svg';
  static const String appIconWhite = 'assets/icons/appiconwht.svg';
  static const String googleIcon = 'assets/icons/google_icon.svg';
  static const String motorPng = 'assets/icons/motor.png';
  static const String motorSvg = 'assets/icons/motor.svg';

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get icon for vehicle type
  static IconData getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'motorcycle':
      case 'bike':
        return motorcycle;
      case 'truck':
      case 'lorry':
        return truck;
      case 'car':
      default:
        return vehicle;
    }
  }

  /// Get icon for battery level
  static IconData getBatteryIcon(int batteryLevel) {
    if (batteryLevel > 75) return batteryFull;
    if (batteryLevel > 50) return batteryHalf;
    if (batteryLevel > 25) return batteryLow;
    return batteryEmpty;
  }

  /// Get icon for signal strength
  static IconData getSignalIcon(int signalStrength) {
    if (signalStrength > 75) return signal;
    if (signalStrength > 25) return signalWeak;
    return signalOff;
  }

  /// Get icon for notification type
  static IconData getNotificationIcon(String notificationType) {
    switch (notificationType.toLowerCase()) {
      case 'alert':
      case 'alarm':
        return notificationAlert;
      case 'warning':
        return warning;
      case 'error':
        return error;
      case 'info':
      case 'information':
        return info;
      case 'success':
        return success;
      default:
        return notificationBell;
    }
  }

  /// Get icon for geofence status
  static IconData getGeofenceIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return geofence;
      case 'add':
      case 'create':
        return geofenceAdd;
      case 'edit':
      case 'modify':
        return geofenceEdit;
      case 'delete':
      case 'remove':
        return geofenceDelete;
      default:
        return geofence;
    }
  }

  /// Get icon for device status
  static IconData getDeviceStatusIcon(bool isOnline, bool hasGps) {
    if (!isOnline) return offline;
    if (!hasGps) return gpsOff;
    return online;
  }
}

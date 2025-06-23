import 'package:intl/intl.dart';

/// Utility service for consistent formatting across the application
class FormattingService {
  // Private constructor to prevent instantiation
  FormattingService._();

  /// Format date and time consistently
  static String formatDateTime(DateTime dateTime, {String? format}) {
    format ??= 'MMM d, yyyy HH:mm';
    return DateFormat(format).format(dateTime);
  }

  /// Format date only
  static String formatDate(DateTime dateTime, {String? format}) {
    format ??= 'MMM d, yyyy';
    return DateFormat(format).format(dateTime);
  }

  /// Format time only
  static String formatTime(DateTime dateTime, {String? format}) {
    format ??= 'HH:mm:ss';
    return DateFormat(format).format(dateTime);
  }

  /// Format to WITA timezone (UTC+8)
  static String formatToWITA(DateTime dateTime) {
    final witaTime = dateTime.toUtc().add(const Duration(hours: 8));
    return '${witaTime.hour.toString().padLeft(2, '0')}:${witaTime.minute.toString().padLeft(2, '0')}:${witaTime.second.toString().padLeft(2, '0')} WITA';
  }

  /// Get relative time (e.g., "2 hours ago", "just now")
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return formatDate(dateTime, format: 'MMM d, yyyy');
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

  /// Format coordinates for display
  static String formatCoordinates(
    double latitude,
    double longitude, {
    int precision = 5,
  }) {
    return 'Lat: ${latitude.toStringAsFixed(precision)}, Lng: ${longitude.toStringAsFixed(precision)}';
  }

  /// Format coordinates as comma-separated string
  static String formatCoordinatesSimple(
    double latitude,
    double longitude, {
    int precision = 4,
  }) {
    return '${latitude.toStringAsFixed(precision)}, ${longitude.toStringAsFixed(precision)}';
  }

  /// Format distance with appropriate unit
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
    }
  }

  /// Format speed with unit
  static String formatSpeed(double speedInKmh) {
    return '${speedInKmh.toStringAsFixed(1)} km/h';
  }

  /// Format vehicle plate number for display
  static String formatPlateNumber(String? plateNumber) {
    if (plateNumber == null || plateNumber.isEmpty) {
      return 'No plate';
    }
    return plateNumber.toUpperCase();
  }

  /// Capitalize first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Format device name for display
  static String formatDeviceName(String deviceName) {
    if (deviceName.isEmpty) return 'Unknown Device';
    return capitalizeWords(deviceName);
  }

  /// Format geofence action for display
  static String formatGeofenceAction(String action) {
    switch (action.toLowerCase()) {
      case 'enter':
      case 'entered':
        return 'ENTERED';
      case 'exit':
      case 'exited':
        return 'EXITED';
      default:
        return action.toUpperCase();
    }
  }

  /// Format notification title
  static String formatNotificationTitle(String? title) {
    if (title == null || title.isEmpty) {
      return 'Notification';
    }
    return capitalizeWords(title);
  }

  /// Format vehicle status
  static String formatVehicleStatus(bool isOn) {
    return isOn ? 'ON' : 'OFF';
  }

  /// Format GPS accuracy
  static String formatGPSAccuracy(double? accuracy) {
    if (accuracy == null) return 'Unknown';
    return '±${accuracy.toStringAsFixed(1)} m';
  }

  /// Format satellite count
  static String formatSatelliteCount(int? satellites) {
    if (satellites == null) return 'No data';
    return '$satellites satellites';
  }

  /// Format battery level
  static String formatBatteryLevel(double? batteryLevel) {
    if (batteryLevel == null) return 'Unknown';
    return '${(batteryLevel * 100).toStringAsFixed(0)}%';
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Format duration
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  /// Format notification group title
  static String formatNotificationGroupTitle(String key, DateTime date) {
    if (key == 'today') return 'Today';
    if (key == 'yesterday') return 'Yesterday';
    if (key.startsWith('thisweek_')) {
      return DateFormat('EEEE').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Format error message for user display
  static String formatErrorMessage(String error) {
    // Remove technical details and provide user-friendly messages
    String cleanError = error.toLowerCase();

    if (cleanError.contains('network') || cleanError.contains('internet')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (cleanError.contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    } else if (cleanError.contains('not found') || cleanError.contains('404')) {
      return 'Requested data not found.';
    } else if (cleanError.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (cleanError.contains('unauthorized') ||
        cleanError.contains('401')) {
      return 'Authentication error. Please log in again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Format boolean as Yes/No
  static String formatBoolean(bool value) {
    return value ? 'Yes' : 'No';
  }

  /// Format vehicle type for display
  static String formatVehicleType(String? vehicleType) {
    if (vehicleType == null || vehicleType.isEmpty) {
      return 'Unknown Type';
    }
    return capitalizeWords(vehicleType);
  }
}

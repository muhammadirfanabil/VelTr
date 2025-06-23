import 'package:intl/intl.dart';

/// Utility class for formatting dates and times in user-friendly ways
class TimeFormatter {
  /// Private constructor to prevent instantiation
  TimeFormatter._();

  /// Format a DateTime to a user-friendly "time ago" string
  static String getTimeAgo(DateTime dateTime) {
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

  /// Format a DateTime to a specific time format (HH:mm)
  static String getFormattedTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Format a DateTime to a specific date format (MMM d, yyyy)
  static String getFormattedDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  /// Format a DateTime to include both date and time
  static String getFormattedDateTime(DateTime dateTime) {
    return DateFormat('MMM d, yyyy • HH:mm').format(dateTime);
  }

  /// Get day name for a given date (e.g., "Monday", "Tuesday")
  static String getDayName(DateTime dateTime) {
    return DateFormat('EEEE').format(dateTime);
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if a date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Check if a date is within the current week
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    return difference.inDays < 7 && difference.inDays >= 0;
  }

  /// Get a contextual date label (Today, Yesterday, Day name, or formatted date)
  static String getContextualDateLabel(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isYesterday(date)) {
      return 'Yesterday';
    } else if (isThisWeek(date)) {
      return getDayName(date);
    } else {
      return getFormattedDate(date);
    }
  }

  /// Format notification timestamp for display
  static String formatNotificationTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Same day - show time only
      return getFormattedTime(timestamp);
    } else if (difference.inDays == 1) {
      // Yesterday - show "Yesterday" + time
      return 'Yesterday • ${getFormattedTime(timestamp)}';
    } else if (difference.inDays < 7) {
      // This week - show day name + time
      return '${getDayName(timestamp)} • ${getFormattedTime(timestamp)}';
    } else {
      // Older - show full date + time
      return getFormattedDateTime(timestamp);
    }
  }

  /// Convert timestamp to epoch milliseconds
  static int toEpochMilliseconds(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch;
  }

  /// Create DateTime from epoch milliseconds
  static DateTime fromEpochMilliseconds(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// Get start of day for a given date
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day for a given date
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get relative time with more granular precision
  static String getDetailedTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return '${years} year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '${months} month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks} week${weeks > 1 ? 's' : ''} ago';
    } else {
      return getTimeAgo(dateTime);
    }
  }
}

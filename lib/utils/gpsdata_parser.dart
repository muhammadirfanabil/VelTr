import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GPSDataParser {
  /// Parses a dynamic value to a double
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parses a dynamic value to an integer
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parses and formats a timestamp string
  static String parseTimestamp(String timestamp) {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return 'Invalid timestamp';
    }
  }
}

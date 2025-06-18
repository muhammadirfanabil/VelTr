import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

class HistoryEntry {
  final String id;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final String vehicleId;
  final String ownerId;

  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.vehicleId,
    required this.ownerId,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map, String id) {
    return HistoryEntry(
      id: id,
      createdAt: DateTime.parse(map['createdAt']),
      latitude: map['location']['latitude'].toDouble(),
      longitude: map['location']['longitude'].toDouble(),
      vehicleId: map['vehicleId'],
      ownerId: map['ownerId'],
    );
  }
}

class HistoryService {
  static FirebaseFunctions? _functionsInstance;

  static FirebaseFunctions get _functions {
    _functionsInstance ??= FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    );
    return _functionsInstance!;
  }

  /// Initialize the service and ensure proper configuration
  static void initialize() {
    // Ensure we're using production endpoints, not emulators
    // This prevents "Failed to resolve name" errors
    print('🔧 [HISTORY] Initializing Firebase Functions for production use');

    // Force initialize the functions instance
    _functions;
  }

  /// Fetch driving history for a vehicle over the specified number of days
  static Future<List<HistoryEntry>> fetchDrivingHistory({
    required String vehicleId,
    int days = 7,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      final callable = _functions.httpsCallable('querydrivinghistory');

      final requestData = {'vehicleId': vehicleId, 'days': days};

      print(
        '🔍 [DEBUG] Calling Cloud Function with vehicleId: $vehicleId, days: $days',
      );
      print('🔍 [DEBUG] Request data: $requestData');
      print('🔍 [DEBUG] Current user: ${user.uid}');

      // Add timeout and better error handling
      final result = await callable
          .call(requestData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Cloud Function call timed out after 30 seconds',
              );
            },
          );

      print('🔍 [DEBUG] Cloud Function response: ${result.data}');
      print('🔍 [DEBUG] Response type: ${result.data.runtimeType}');
      print('🔍 [DEBUG] Response keys: ${result.data?.keys?.toList()}');

      final data = result.data;
      if (data == null) {
        throw Exception('No data received from Cloud Function');
      }

      if (data['success'] != true) {
        final errorMsg = data['error'] ?? 'Unknown error from Cloud Function';
        print('🔍 [DEBUG] Cloud Function returned error: $errorMsg');
        throw Exception(errorMsg);
      }
      final List<dynamic> entries = data['entries'] ?? [];

      // Add debug logging
      print('Fetched ${entries.length} history entries for vehicle $vehicleId');
      if (entries.isEmpty) {
        print('No history data found. This could mean:');
        print('1. Vehicle has no GPS data logged yet');
        print('2. Device is not linked to vehicle');
        print('3. No movement detected in the specified time range');
      }

      return entries
          .map((entry) => HistoryEntry.fromMap(entry, entry['id']))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      print('🔥 [ERROR] Firebase Functions Exception:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.details}');

      switch (e.code) {
        case 'unauthenticated':
          throw Exception('User authentication failed. Please log in again.');
        case 'permission-denied':
          throw Exception('Access denied. You do not own this vehicle.');
        case 'not-found':
          throw Exception('Vehicle not found or function unavailable.');
        case 'unavailable':
          throw Exception(
            'Service temporarily unavailable. Please try again later.',
          );
        case 'internal':
          throw Exception('Internal server error. Please try again later.');
        default:
          throw Exception('Firebase Functions Error: ${e.message}');
      }
    } on TimeoutException catch (e) {
      print('⏰ [ERROR] Timeout: ${e.message}');
      throw Exception(
        'Request timed out. Please check your connection and try again.',
      );
    } on PlatformException catch (e) {
      print('📱 [ERROR] Platform Exception:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.details}');
      throw Exception(
        'Platform error: ${e.message ?? 'Unknown platform error'}',
      );
    } catch (e) {
      print('❌ [ERROR] General Exception:');
      print('  Type: ${e.runtimeType}');
      print('  Message: $e');

      // Handle specific error patterns
      if (e.toString().contains('Failed to resolve name')) {
        throw Exception(
          'Network connection error. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('INTERNAL')) {
        throw Exception('Internal service error. Please try again later.');
      } else {
        throw Exception('Failed to fetch driving history: ${e.toString()}');
      }
    }
  }

  /// Get the total distance traveled for a vehicle over the specified period
  static double calculateTotalDistance(List<HistoryEntry> entries) {
    if (entries.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < entries.length; i++) {
      final prev = entries[i - 1];
      final current = entries[i];

      // Calculate distance using Haversine formula
      totalDistance += _calculateDistanceBetweenPoints(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
    }

    return totalDistance;
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistanceBetweenPoints(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get driving statistics for a vehicle
  static Map<String, dynamic> getDrivingStatistics(List<HistoryEntry> entries) {
    if (entries.isEmpty) {
      return {
        'totalDistance': 0.0,
        'totalPoints': 0,
        'firstPoint': null,
        'lastPoint': null,
        'timeSpan': Duration.zero,
      };
    }

    final totalDistance = calculateTotalDistance(entries);
    final firstPoint = entries.first;
    final lastPoint = entries.last;
    final timeSpan = lastPoint.createdAt.difference(firstPoint.createdAt);

    return {
      'totalDistance': totalDistance,
      'totalPoints': entries.length,
      'firstPoint': firstPoint,
      'lastPoint': lastPoint,
      'timeSpan': timeSpan,
    };
  }
}

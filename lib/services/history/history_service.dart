import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

class HistoryEntry {
  final String id;
  final DateTime createdAt; // Always stored as UTC, displayed as local
  final DateTime createdAtUTC; // Explicit UTC timestamp for reference
  final double latitude;
  final double longitude;
  final String vehicleId;
  final String ownerId;
  final String deviceName;
  final Map<String, dynamic>? metadata;

  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.createdAtUTC,
    required this.latitude,
    required this.longitude,
    required this.vehicleId,
    required this.ownerId,
    required this.deviceName,
    this.metadata,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map, String id) {
    try {
      // Handle different date formats from Cloud Functions
      DateTime createdAtUTC;

      // Try multiple timestamp formats
      if (map['createdAt'] is String) {
        // ISO string format (preferred)
        createdAtUTC = DateTime.parse(map['createdAt']).toUtc();
      } else if (map['createdAtTimestamp'] is int) {
        // Unix timestamp
        createdAtUTC =
            DateTime.fromMillisecondsSinceEpoch(
              map['createdAtTimestamp'],
            ).toUtc();
      } else if (map['createdAt'] is int) {
        // Fallback unix timestamp
        createdAtUTC =
            DateTime.fromMillisecondsSinceEpoch(map['createdAt']).toUtc();
      } else {
        print(
          '⚠️ [WARNING] Unknown createdAt format: ${map['createdAt']}, using current time',
        );
        createdAtUTC = DateTime.now().toUtc(); // Fallback
      }

      // Convert UTC to local time for display
      final createdAtLocal = createdAtUTC.toLocal();

      // Safely extract location data
      final dynamic locationData = map['location'];
      final Map<String, dynamic> location;

      if (locationData is Map) {
        location = Map<String, dynamic>.from(locationData);
      } else {
        throw Exception('Invalid location data format');
      }

      return HistoryEntry(
        id: id,
        createdAt: createdAtLocal, // Local time for display
        createdAtUTC: createdAtUTC, // UTC for reference/calculations
        latitude: (location['latitude'] ?? 0.0).toDouble(),
        longitude: (location['longitude'] ?? 0.0).toDouble(),
        vehicleId: map['vehicleId']?.toString() ?? '',
        ownerId: map['ownerId']?.toString() ?? '',
        deviceName:
            map['deviceName']?.toString() ??
            map['firestoreDeviceId']?.toString() ??
            'Unknown Device',
        metadata: map['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print('❌ Error parsing HistoryEntry: $e');
      print('❌ Raw data: $map');
      rethrow;
    }
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

      // Fix: Properly cast the response data to handle Firebase type issues
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        result.data as Map,
      );

      if (data['success'] != true) {
        final errorMsg = data['error'] ?? 'Unknown error from Cloud Function';
        print('🔍 [DEBUG] Cloud Function returned error: $errorMsg');
        throw Exception(errorMsg);
      }

      // Fix: Safely cast the entries array
      final List<dynamic> rawEntries = data['entries'] ?? [];

      // Add debug logging
      print(
        'Fetched ${rawEntries.length} history entries for vehicle $vehicleId',
      );
      if (rawEntries.isEmpty) {
        print('No history data found. This could mean:');
        print('1. Vehicle has no GPS data logged yet');
        print('2. Device is not linked to vehicle');
        print('3. No movement detected in the specified time range');
        return [];
      }

      // Fix: Properly cast each entry and handle potential type issues
      final List<HistoryEntry> entries = [];

      for (int i = 0; i < rawEntries.length; i++) {
        try {
          // Safely cast each entry to Map<String, dynamic>
          final Map<String, dynamic> entryMap = Map<String, dynamic>.from(
            rawEntries[i] as Map,
          );

          // Generate ID if missing
          final String entryId = entryMap['id']?.toString() ?? 'entry_$i';

          final entry = HistoryEntry.fromMap(entryMap, entryId);
          entries.add(entry);
        } catch (entryError) {
          print(
            '⚠️ [WARNING] Skipping malformed entry at index $i: $entryError',
          );
          print('⚠️ [WARNING] Raw entry data: ${rawEntries[i]}');
          // Continue processing other entries instead of failing completely
        }
      }

      print('✅ Successfully parsed ${entries.length} valid history entries');
      return entries;
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
      } else if (e.toString().contains('subtype')) {
        throw Exception(
          'Data format error. Please try again or contact support.',
        );
      } else if (e.toString().contains('_TypeError')) {
        throw Exception(
          'Data type mismatch error. The server response format may have changed.',
        );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_app/services/history/history_service.dart';

void main() {
  group('History Service UTC Timestamp Tests', () {
    test('Should properly parse UTC timestamp and convert to local time', () {
      // Mock data that would come from the Cloud Function
      final mockCloudFunctionResponse = {
        'id': 'test_entry_1',
        'createdAt': '2025-07-05T14:30:00.000Z', // UTC ISO string
        'createdAtTimestamp': 1751725800000, // Unix timestamp
        'location': {
          'latitude': -6.2088,
          'longitude': 106.8456,
        },
        'vehicleId': 'test_vehicle_123',
        'ownerId': 'test_owner_456',
        'deviceName': 'Test Device',
        'metadata': {
          'loggedAtUTC': '2025-07-05T14:30:00.000Z',
          'loggedAtTimestamp': 1751725800000,
          'distance': 0.15,
          'timeSinceLastEntry': 900000, // 15 minutes
          'logReason': 'Time and location criteria met (15.0 min, 150m)',
          'source': 'processdrivinghistory',
          'version': '2.0'
        }
      };

      // Parse using the HistoryEntry.fromMap factory
      final historyEntry = HistoryEntry.fromMap(mockCloudFunctionResponse, 'test_entry_1');

      // Verify the entry was parsed correctly
      expect(historyEntry.id, equals('test_entry_1'));
      expect(historyEntry.latitude, equals(-6.2088));
      expect(historyEntry.longitude, equals(106.8456));
      expect(historyEntry.vehicleId, equals('test_vehicle_123'));
      expect(historyEntry.ownerId, equals('test_owner_456'));
      expect(historyEntry.deviceName, equals('Test Device'));

      // Verify UTC timestamp handling
      expect(historyEntry.createdAtUTC.isUtc, isTrue);
      expect(historyEntry.createdAtUTC.toIso8601String(), equals('2025-07-05T14:30:00.000Z'));

      // Verify local time conversion
      // Note: The exact local time will depend on the system timezone
      // but we can verify it's different from UTC (unless the system is in UTC)
      final localTime = historyEntry.createdAt;
      final utcTime = historyEntry.createdAtUTC;
      
      // The local time should be the same instant as UTC, just in local timezone
      expect(localTime.millisecondsSinceEpoch, equals(utcTime.millisecondsSinceEpoch));
      
      // But the time zone should be different (unless system is UTC)
      if (DateTime.now().timeZoneOffset != Duration.zero) {
        expect(localTime.isUtc, isFalse);
      }

      print('✅ UTC Time: ${utcTime.toIso8601String()}');
      print('✅ Local Time: ${localTime.toString()}');
      print('✅ System Timezone Offset: ${DateTime.now().timeZoneOffset}');
    });

    test('Should handle different timestamp formats', () {
      // Test with ISO string format
      final isoResponse = {
        'id': 'test_iso',
        'createdAt': '2025-07-05T14:30:00.000Z',
        'location': {'latitude': -6.2088, 'longitude': 106.8456},
        'vehicleId': 'test_vehicle',
        'ownerId': 'test_owner',
        'deviceName': 'Test Device',
      };

      final isoEntry = HistoryEntry.fromMap(isoResponse, 'test_iso');
      expect(isoEntry.createdAtUTC.toIso8601String(), equals('2025-07-05T14:30:00.000Z'));

      // Test with Unix timestamp format
      final unixResponse = {
        'id': 'test_unix',
        'createdAtTimestamp': 1751725800000,
        'location': {'latitude': -6.2088, 'longitude': 106.8456},
        'vehicleId': 'test_vehicle',
        'ownerId': 'test_owner',
        'deviceName': 'Test Device',
      };

      final unixEntry = HistoryEntry.fromMap(unixResponse, 'test_unix');
      expect(unixEntry.createdAtUTC.toIso8601String(), equals('2025-07-05T14:30:00.000Z'));

      // Both should represent the same time
      expect(isoEntry.createdAtUTC.millisecondsSinceEpoch, 
             equals(unixEntry.createdAtUTC.millisecondsSinceEpoch));
    });

    test('Should calculate driving statistics correctly', () {
      // Create test entries with different coordinates and times
      final entries = [
        HistoryEntry(
          id: 'entry1',
          createdAt: DateTime.parse('2025-07-05T10:00:00Z').toLocal(),
          createdAtUTC: DateTime.parse('2025-07-05T10:00:00Z'),
          latitude: -6.2088,
          longitude: 106.8456,
          vehicleId: 'test_vehicle',
          ownerId: 'test_owner',
          deviceName: 'Test Device',
        ),
        HistoryEntry(
          id: 'entry2',
          createdAt: DateTime.parse('2025-07-05T10:15:00Z').toLocal(),
          createdAtUTC: DateTime.parse('2025-07-05T10:15:00Z'),
          latitude: -6.2100, // About 200m away
          longitude: 106.8470,
          vehicleId: 'test_vehicle',
          ownerId: 'test_owner',
          deviceName: 'Test Device',
        ),
        HistoryEntry(
          id: 'entry3',
          createdAt: DateTime.parse('2025-07-05T10:30:00Z').toLocal(),
          createdAtUTC: DateTime.parse('2025-07-05T10:30:00Z'),
          latitude: -6.2120, // Another 200m away
          longitude: 106.8490,
          vehicleId: 'test_vehicle',
          ownerId: 'test_owner',
          deviceName: 'Test Device',
        ),
      ];

      final stats = HistoryService.getDrivingStatistics(entries);
      
      expect(stats['totalPoints'], equals(3));
      expect(stats['firstPoint'], equals(entries.first));
      expect(stats['lastPoint'], equals(entries.last));
      expect(stats['timeSpan'], equals(const Duration(minutes: 30)));
      
      // Distance should be greater than 0 (approximately 400m total)
      final totalDistance = stats['totalDistance'] as double;
      expect(totalDistance, greaterThan(300)); // At least 300m
      expect(totalDistance, lessThan(600)); // But less than 600m

      print('✅ Total distance calculated: ${totalDistance.toStringAsFixed(0)}m');
      print('✅ Time span: ${stats['timeSpan']}');
    });

    test('Should demonstrate proper 15-minute interval with display times', () {
      // Simulate the backend 15-minute interval enforcement
      final now = DateTime.now().toUtc();
      
      // First entry (would be logged)
      final firstEntry = HistoryEntry(
        id: 'first',
        createdAt: now.toLocal(),
        createdAtUTC: now,
        latitude: -6.2088,
        longitude: 106.8456,
        vehicleId: 'test_vehicle',
        ownerId: 'test_owner',
        deviceName: 'Test Device',
        metadata: {
          'logReason': 'First entry for vehicle',
          'timeSinceLastEntry': 0,
        }
      );

      // Second entry 5 minutes later (would be skipped by backend)
      // This entry wouldn't actually exist due to backend filtering

      // Third entry 15 minutes later (would be logged)
      final validTime = now.add(const Duration(minutes: 15));
      final validEntry = HistoryEntry(
        id: 'valid',
        createdAt: validTime.toLocal(),
        createdAtUTC: validTime,
        latitude: -6.2100,
        longitude: 106.8470,
        vehicleId: 'test_vehicle',
        ownerId: 'test_owner',
        deviceName: 'Test Device',
        metadata: {
          'logReason': 'Time and location criteria met (15.0 min, 150m)',
          'timeSinceLastEntry': 900000, // 15 minutes in ms
          'distance': 0.15, // 150m in km
        }
      );

      // Verify the entries demonstrate proper 15-minute spacing
      final timeDiff = validEntry.createdAtUTC.difference(firstEntry.createdAtUTC);
      expect(timeDiff.inMinutes, equals(15));

      print('✅ First entry time (local): ${firstEntry.createdAt}');
      print('✅ First entry time (UTC): ${firstEntry.createdAtUTC.toIso8601String()}');
      print('✅ Valid entry time (local): ${validEntry.createdAt}');
      print('✅ Valid entry time (UTC): ${validEntry.createdAtUTC.toIso8601String()}');
      print('✅ Time difference: ${timeDiff.inMinutes} minutes');
      print('✅ Log reason: ${validEntry.metadata?['logReason']}');
    });
  });
}

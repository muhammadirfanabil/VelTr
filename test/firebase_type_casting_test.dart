import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_database/firebase_database.dart';
import '../lib/services/device/deviceService.dart';

// Mock classes for testing
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockDatabaseReference extends Mock implements DatabaseReference {}

class MockDataSnapshot extends Mock implements DataSnapshot {}

void main() {
  group('Firebase Type Casting Tests', () {
    late DeviceService deviceService;
    late MockFirebaseDatabase mockRealtimeDB;
    late MockDatabaseReference mockRef;
    late MockDataSnapshot mockSnapshot;

    setUp(() {
      mockRealtimeDB = MockFirebaseDatabase();
      mockRef = MockDatabaseReference();
      mockSnapshot = MockDataSnapshot();

      deviceService = DeviceService(realtimeDB: mockRealtimeDB);
    });

    test('should handle Firebase _Map<Object?, Object?> type safely', () async {
      // Simulate Firebase Realtime Database returning _Map<Object?, Object?>
      final firebaseMapData = <Object?, Object?>{
        'gps': <Object?, Object?>{
          'latitude': -8.123456,
          'longitude': 115.123456,
          'altitude_m': 100.5,
          'speed_kmph': 30.2,
          'course_deg': 45.0,
        },
        'relay': true,
        'device_id': 'B0A7322B2EC4',
      };

      // Setup mocks
      when(mockRealtimeDB.ref('devices/B0A7322B2EC4')).thenReturn(mockRef);
      when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(firebaseMapData);

      // Test that the method doesn't throw type casting errors
      final result = await deviceService.validateDeviceInRealtimeDB(
        'B0A7322B2EC4',
      );

      expect(result, isTrue);
    });

    test('should extract GPS data safely from Firebase Map', () async {
      // Test data structure similar to what Firebase returns
      final testMetadata = <String, dynamic>{
        'gps': <Object?, Object?>{
          'latitude': -8.123456,
          'longitude': 115.123456,
          'altitude_m': 100.5,
          'speed_kmph': 30.2,
          'course_deg': 45.0,
        },
        'relay': true,
      };

      // This should not throw any type casting errors
      expect(() {
        final gpsData = testMetadata['gps'];
        if (gpsData is Map) {
          final safeData = <String, dynamic>{};
          for (final entry in gpsData.entries) {
            final key = entry.key?.toString() ?? '';
            final value = entry.value;
            if (key.isNotEmpty) {
              safeData[key] = value;
            }
          }
          expect(safeData['latitude'], equals(-8.123456));
          expect(safeData['longitude'], equals(115.123456));
        }
      }, returnsNormally);
    });

    test('should handle null and empty GPS data gracefully', () async {
      // Test with null GPS data
      final nullGpsMetadata = <String, dynamic>{'gps': null, 'relay': true};

      expect(() {
        final gpsData = nullGpsMetadata['gps'];
        if (gpsData is Map) {
          // This branch should not execute
          fail('Should not reach this branch with null GPS data');
        }
        // Should handle null gracefully
      }, returnsNormally);

      // Test with empty GPS data
      final emptyGpsMetadata = <String, dynamic>{
        'gps': <Object?, Object?>{},
        'relay': true,
      };

      expect(() {
        final gpsData = emptyGpsMetadata['gps'];
        if (gpsData is Map) {
          final safeData = <String, dynamic>{};
          for (final entry in gpsData.entries) {
            final key = entry.key?.toString() ?? '';
            final value = entry.value;
            if (key.isNotEmpty) {
              safeData[key] = value;
            }
          }
          expect(safeData.isEmpty, isTrue);
        }
      }, returnsNormally);
    });
  });
}

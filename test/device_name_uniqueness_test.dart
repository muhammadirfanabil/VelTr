import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/services/device/deviceService.dart';
import '../lib/models/Device/device.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  group('Device Name Uniqueness Validation', () {
    late DeviceService deviceService;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockCollectionReference mockCollection;
    late MockQuery mockQuery;
    late MockQuerySnapshot mockSnapshot;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockCollection = MockCollectionReference();
      mockQuery = MockQuery();
      mockSnapshot = MockQuerySnapshot();

      deviceService = DeviceService(
        firestoreInstance: mockFirestore,
        auth: mockAuth,
      );

      // Setup common mocks
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-user-id');
      when(mockFirestore.collection('devices')).thenReturn(mockCollection);
    });

    test('should allow unique device names', () async {
      // Arrange
      when(
        mockCollection.where('name', isEqualTo: 'UniqueDevice'),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(
        mockSnapshot.docs,
      ).thenReturn([]); // No existing devices with this name

      // Act & Assert
      expect(
        () async => await deviceService.addDevice(name: 'UniqueDevice'),
        isNot(throwsException),
      );
    });

    test('should reject duplicate device names', () async {
      // Arrange
      final mockDoc = MockQueryDocumentSnapshot();
      when(mockDoc.id).thenReturn('existing-device-id');

      when(
        mockCollection.where('name', isEqualTo: 'DuplicateDevice'),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(
        mockSnapshot.docs,
      ).thenReturn([mockDoc]); // Existing device with this name

      // Act & Assert
      expect(
        () async => await deviceService.addDevice(name: 'DuplicateDevice'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Device name "DuplicateDevice" is already in use'),
          ),
        ),
      );
    });

    test('should allow updating device with same name (self)', () async {
      // Arrange
      final mockDoc = MockQueryDocumentSnapshot();
      when(mockDoc.id).thenReturn('device-id-123');

      when(
        mockCollection.where('name', isEqualTo: 'ExistingDevice'),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.docs).thenReturn([mockDoc]); // Same device

      // Create a mock device
      final device = Device(
        id: 'device-id-123',
        name: 'ExistingDevice',
        ownerId: 'test-user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(
        () async => await deviceService.updateDevice(device),
        isNot(throwsException),
      );
    });

    test('should reject updating device to duplicate name', () async {
      // Arrange
      final mockDoc = MockQueryDocumentSnapshot();
      when(mockDoc.id).thenReturn('different-device-id');

      when(
        mockCollection.where('name', isEqualTo: 'ExistingDevice'),
      ).thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(
        mockSnapshot.docs,
      ).thenReturn([mockDoc]); // Different device with this name

      // Create a mock device trying to update to existing name
      final device = Device(
        id: 'device-id-123',
        name: 'ExistingDevice',
        ownerId: 'test-user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act & Assert
      expect(
        () async => await deviceService.updateDevice(device),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Device name "ExistingDevice" is already in use'),
          ),
        ),
      );
    });
  });
}

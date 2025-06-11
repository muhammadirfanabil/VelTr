import 'package:flutter_test/flutter_test.dart';
import '../lib/services/device/deviceService.dart';

void main() {
  group('Device Service Tests', () {
    test('getVehicleIdsByDeviceId should return correct method signature', () {
      // This test verifies that our new method exists and has the correct signature
      final deviceService = DeviceService();

      // Test that the method exists and returns the correct type
      expect(deviceService.getVehicleIdsByDeviceId, isA<Function>());

      // The method should return Future<List<String>>
      expect(
        deviceService.getVehicleIdsByDeviceId('test-id'),
        isA<Future<List<String>>>(),
      );
    });

    test('deleteDevice method should exist and be callable', () {
      // This test verifies that our enhanced deleteDevice method exists
      final deviceService = DeviceService();

      // Test that the method exists
      expect(deviceService.deleteDevice, isA<Function>());

      // The method should return Future<void>
      expect(deviceService.deleteDevice('test-id'), isA<Future<void>>());
    });
  });
}

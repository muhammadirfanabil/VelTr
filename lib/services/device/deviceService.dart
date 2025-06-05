import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../models/Device/device.dart';

/// Service class for handling device-related operations
class DeviceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a new DeviceService instance
  DeviceService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Returns a stream of devices for the current user
  Stream<List<Device>> getDevicesStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: currentUser.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Device.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  Stream<Device> getDeviceStream(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) => Device.fromMap(doc.data()!, doc.id));
  }

  /// Adds a new device for the current user
  Future<Device> addDevice({
    required String name,
    String? vehicleId,
    Map<String, double>? gpsData,
    bool isActive = true,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _firestore.collection('devices').doc();
    final newDevice = Device(
      id: docRef.id,
      name: name,
      ownerId: currentUser.uid,
      vehicleId: vehicleId,
      gpsData: gpsData ?? {},
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newDevice.toMap());
    return newDevice;
  }

  /// Updates an existing device
  Future<void> updateDevice(Device deviceToUpdate) async {
    await _firestore
        .collection('devices')
        .doc(deviceToUpdate.id)
        .update(deviceToUpdate.copyWith(updatedAt: DateTime.now()).toMap());
  }

  /// Updates device GPS data
  Future<void> updateDeviceGPS({
    required String deviceId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    double? heading,
  }) async {
    final gpsData = <String, double>{
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
    };

    await _firestore.collection('devices').doc(deviceId).update({
      'gpsData': gpsData,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Assign device to a vehicle
  Future<void> assignDeviceToVehicle(String deviceId, String vehicleId) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'vehicleId': vehicleId,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Unassign device from vehicle
  Future<void> unassignDeviceFromVehicle(String deviceId) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'vehicleId': null,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Toggle device active status
  Future<void> toggleDeviceStatus(String deviceId, bool isActive) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'isActive': isActive,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes a device
  Future<void> deleteDevice(String id) async {
    await _firestore.collection('devices').doc(id).delete();
  }

  /// Gets a single device by ID
  Future<Device?> getDeviceById(String id) async {
    final doc = await _firestore.collection('devices').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return Device.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get device by vehicle ID
  Future<Device?> getDeviceByVehicleId(String vehicleId) async {
    final snapshot =
        await _firestore
            .collection('devices')
            .where('vehicleId', isEqualTo: vehicleId)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      return Device.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  /// Get devices that are not assigned to any vehicle
  Future<List<Device>> getUnassignedDevices() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot =
        await _firestore
            .collection('devices')
            .where('ownerId', isEqualTo: currentUser.uid)
            .where('vehicleId', isNull: true)
            .get();

    return snapshot.docs
        .map((doc) => Device.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Get devices with valid GPS data
  Future<List<Device>> getDevicesWithValidGPS() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot =
        await _firestore
            .collection('devices')
            .where('ownerId', isEqualTo: currentUser.uid)
            .where('isActive', isEqualTo: true)
            .get();

    return snapshot.docs
        .map((doc) => Device.fromMap(doc.data(), doc.id))
        .where((device) => device.hasValidGPS)
        .toList();
  }

  /// Stream devices with GPS data for real-time tracking
  Stream<List<Device>> getActiveDevicesWithGPSStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: currentUser.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Device.fromMap(doc.data(), doc.id))
                  .where((device) => device.hasValidGPS)
                  .toList(),
        );
  }

  /// Batch update multiple device locations
  Future<void> batchUpdateDeviceLocations(
    Map<String, Map<String, double>> deviceLocationMap,
  ) async {
    final batch = _firestore.batch();
    final timestamp = Timestamp.fromDate(DateTime.now());

    for (final entry in deviceLocationMap.entries) {
      final deviceRef = _firestore.collection('devices').doc(entry.key);
      batch.update(deviceRef, {
        'gpsData': entry.value,
        'updated_at': timestamp,
      });
    }

    await batch.commit();
  }

  /// Get the current user's primary device ID for map tracking
  /// Returns the device ID (MAC ID) that corresponds to the physical GPS device
  /// Priority: Active device with valid GPS data > Any active device > Any device
  Future<String?> getCurrentUserPrimaryDeviceId() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    try {
      // Get all user's devices
      final snapshot =
          await _firestore
              .collection('devices')
              .where('ownerId', isEqualTo: currentUser.uid)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final devices =
          snapshot.docs
              .map((doc) => Device.fromMap(doc.data(), doc.id))
              .toList();

      // Priority 1: Active device with valid GPS data
      final activeDevicesWithGPS =
          devices
              .where((device) => device.isActive && device.hasValidGPS)
              .toList();

      if (activeDevicesWithGPS.isNotEmpty) {
        // Return the device ID (which should be the MAC ID for FRDB access)
        return activeDevicesWithGPS.first.id;
      }

      // Priority 2: Any active device
      final activeDevices = devices.where((device) => device.isActive).toList();

      if (activeDevices.isNotEmpty) {
        return activeDevices.first.id;
      }

      // Priority 3: Any device
      return devices.first.id;
    } catch (e) {
      throw Exception('Failed to get primary device: $e');
    }
  }

  /// Get device name by device ID for display purposes
  /// The device ID should be the MAC ID of the physical GPS device
  Future<String?> getDeviceNameById(String deviceId) async {
    try {
      final device = await getDeviceById(deviceId);
      return device?.name;
    } catch (e) {
      return null;
    }
  }

  /// Get device information by MAC ID (device name)
  /// Since MAC ID is stored as device name, this searches by name field
  Future<Device?> getDeviceByMacId(String macId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    try {
      final snapshot =
          await _firestore
              .collection('devices')
              .where('ownerId', isEqualTo: currentUser.uid)
              .where('name', isEqualTo: macId)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return Device.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting device by MAC ID: $e');
      return null;
    }
  }

  /// Get physical device MAC ID from user's device record
  /// This is the bridge method that ensures we get the correct MAC ID for FRDB access
  /// The device name in Firestore should match the MAC ID used in Firebase Realtime Database
  Future<String?> getPhysicalDeviceMacId(String userDeviceId) async {
    try {
      final device = await getDeviceById(userDeviceId);
      if (device != null && device.ownerId == _auth.currentUser?.uid) {
        // The device.name should be the MAC ID (e.g., "B0A7322B2EC4")
        // This creates the bridge between Firestore device records and FRDB GPS data
        debugPrint(
          'Bridge: Found device ${device.name} for user device ID: $userDeviceId',
        );
        return device.name; // Return device name as MAC ID
      }
      debugPrint(
        'Bridge: Device not found or unauthorized access for ID: $userDeviceId',
      );
      return null;
    } catch (e) {
      debugPrint('Error getting physical device MAC ID: $e');
      return null;
    }
  }

  /// Validate that a device MAC ID exists in Firebase Realtime Database
  /// This ensures the bridge between Firestore device records and FRDB GPS data works
  /// Path format: devices/{macId}/gps
  Future<bool> validateDeviceInRealtimeDB(String deviceMacId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('devices/$deviceMacId');
      final snapshot = await ref.get();
      final exists = snapshot.exists;
      debugPrint('Bridge: Device $deviceMacId exists in FRDB: $exists');
      return exists;
    } catch (e) {
      debugPrint('Error validating device in FRDB: $e');
      return false;
    }
  }

  /// Complete bridge method: Get validated MAC ID for map service
  /// 1. Gets user's primary device from Firestore
  /// 2. Extracts MAC ID from device name
  /// 3. Validates MAC ID exists in Firebase Realtime Database
  /// 4. Returns MAC ID for mapService to use with FRDB
  Future<String?> getValidatedDeviceMacIdForMap() async {
    try {
      // Step 1: Get user's primary device ID from Firestore
      final primaryDeviceId = await getCurrentUserPrimaryDeviceId();
      if (primaryDeviceId == null) {
        debugPrint('Bridge: No primary device found for user');
        return null;
      }

      // Step 2: Get the MAC ID from the device record
      final macId = await getPhysicalDeviceMacId(primaryDeviceId);
      if (macId == null) {
        debugPrint('Bridge: Could not extract MAC ID from device');
        return null;
      }

      // Step 3: Validate MAC ID exists in Firebase Realtime Database
      final isValidInFRDB = await validateDeviceInRealtimeDB(macId);
      if (!isValidInFRDB) {
        debugPrint(
          'Bridge: MAC ID $macId not found in Firebase Realtime Database',
        );
        debugPrint(
          'Bridge: Make sure your physical GPS device is sending data to devices/$macId/gps',
        );
        return null;
      }

      debugPrint(
        'Bridge: Successfully validated MAC ID $macId for map service',
      );
      return macId;
    } catch (e) {
      debugPrint('Error in bridge validation: $e');
      return null;
    }
  }

  /// Stream version of the validated device MAC ID for real-time updates
  Stream<String?> getValidatedDeviceMacIdStream() {
    return getCurrentUserPrimaryDeviceIdStream().asyncMap((deviceId) async {
      if (deviceId == null) return null;

      final macId = await getPhysicalDeviceMacId(deviceId);
      if (macId == null) return null;

      final isValid = await validateDeviceInRealtimeDB(macId);
      return isValid ? macId : null;
    });
  }

  /// Stream of current user's primary device ID with real-time updates
  Stream<String?> getCurrentUserPrimaryDeviceIdStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final devices =
              snapshot.docs
                  .map((doc) => Device.fromMap(doc.data(), doc.id))
                  .toList();

          // Priority 1: Active device with valid GPS data
          final activeDevicesWithGPS =
              devices
                  .where((device) => device.isActive && device.hasValidGPS)
                  .toList();

          if (activeDevicesWithGPS.isNotEmpty) {
            return activeDevicesWithGPS.first.id;
          }

          // Priority 2: Any active device
          final activeDevices =
              devices.where((device) => device.isActive).toList();

          if (activeDevices.isNotEmpty) {
            return activeDevices.first.id;
          }

          // Priority 3: Any device
          return devices.first.id;
        });
  }
}

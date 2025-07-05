import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as database;
import 'package:flutter/foundation.dart';
import '../../models/Device/device.dart';

class DeviceService {
  final firestore.FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final database.FirebaseDatabase _realtimeDB;

  DeviceService({
    firestore.FirebaseFirestore? firestoreInstance,
    FirebaseAuth? auth,
    database.FirebaseDatabase? realtimeDB,
  }) : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _realtimeDB = realtimeDB ?? database.FirebaseDatabase.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  // Streams
  Stream<List<Device>> getDevicesStream() {
    if (_currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: _currentUserId)
        .snapshots()
        .map(_docsToDevices);
  }

  Stream<Device?> getDeviceStream(String deviceId) {
    return _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists
                  ? Device.fromMap(snapshot.data()!, snapshot.id)
                  : null,
        );
  }

  Stream<List<Device>> getActiveDevicesWithGPSStream() {
    if (_currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: _currentUserId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              _docsToDevices(
                snapshot,
              ).where((device) => device.hasValidGPS).toList(),
        );
  }

  // Helper method to check device name uniqueness
  Future<bool> _checkDeviceNameUniqueness(
    String name, {
    String? excludeDeviceId,
  }) async {
    final query = _firestore
        .collection('devices')
        .where('name', isEqualTo: name);

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      return true; // Name is unique
    }

    // If we're updating a device, exclude the current device from the check
    if (excludeDeviceId != null) {
      return snapshot.docs.every((doc) => doc.id == excludeDeviceId);
    }

    return false; // Name already exists
  }

  /// Enhanced validation: Check if device exists in Firebase Realtime Database
  Future<bool> _validateDeviceExistsInRealtimeDB(String deviceName) async {
    try {
      debugPrint('🔍 Checking if device "$deviceName" exists in FRDB...');

      final ref = _realtimeDB.ref('devices/$deviceName');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        debugPrint('✅ Device "$deviceName" found in FRDB');
        return true;
      } else {
        debugPrint('❌ Device "$deviceName" not found in FRDB');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking device existence in FRDB: $e');
      return false;
    }
  }

  /// Enhanced validation: Check if device.name matches devices/{deviceId} in FRDB
  /// This ensures the device name corresponds to the actual device ID in the system
  Future<bool> _validateDeviceNameMatchesRealtimeDBId(String deviceName) async {
    try {
      debugPrint(
        '🔍 Validating device name matches FRDB device ID: "$deviceName"',
      );

      // Check if the path devices/{deviceName} exists and has valid data structure
      final ref = _realtimeDB.ref('devices/$deviceName');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        debugPrint(
          '❌ Device path "devices/$deviceName" does not exist in FRDB',
        );
        return false;
      } // Safe type casting for Firebase Realtime Database data
      Map<String, dynamic> deviceData;
      if (snapshot.value is Map) {
        final rawMap = snapshot.value as Map;
        deviceData = <String, dynamic>{};

        // Safely convert each key-value pair
        for (final entry in rawMap.entries) {
          final key = entry.key?.toString() ?? '';
          final value = entry.value;
          if (key.isNotEmpty) {
            deviceData[key] = value;
          }
        }
      } else {
        debugPrint('❌ Device data is not a valid Map structure');
        return false;
      }

      // Check if device has essential data structure (GPS data, relay control, etc.)
      final hasGpsData = deviceData.containsKey('gps');
      final hasRelayControl = deviceData.containsKey('relay');
      final hasValidStructure = hasGpsData || hasRelayControl;

      if (!hasValidStructure) {
        debugPrint(
          '❌ Device "$deviceName" exists but has invalid data structure',
        );
        return false;
      } // Optional: Additional validation - check if device has recent GPS activity
      if (hasGpsData) {
        // Safe type casting for GPS data
        Map<String, dynamic>? gpsData;
        final rawGpsData = deviceData['gps'];
        if (rawGpsData is Map) {
          gpsData = <String, dynamic>{};
          for (final entry in rawGpsData.entries) {
            final key = entry.key?.toString() ?? '';
            final value = entry.value;
            if (key.isNotEmpty) {
              gpsData[key] = value;
            }
          }
        }

        if (gpsData != null) {
          final lat = gpsData['latitude'];
          final lng = gpsData['longitude'];

          // Check if GPS coordinates are valid (not 0,0 or null)
          if (lat == null || lng == null || (lat == 0 && lng == 0)) {
            debugPrint('⚠️ Device "$deviceName" has invalid GPS coordinates');
            // Don't fail validation, just warn - device might be offline temporarily
          }
        }
      }

      debugPrint(
        '✅ Device name "$deviceName" matches FRDB device ID and has valid structure',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error validating device name match: $e');
      return false;
    }
  }

  /// Get device metadata from Firebase Realtime Database
  Future<Map<String, dynamic>?> _getDeviceMetadataFromRealtimeDB(
    String deviceName,
  ) async {
    try {
      final ref = _realtimeDB.ref('devices/$deviceName');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        // Safe type casting for Firebase Realtime Database data
        Map<String, dynamic> data;
        if (snapshot.value is Map) {
          final rawMap = snapshot.value as Map;
          data = <String, dynamic>{};

          // Safely convert each key-value pair
          for (final entry in rawMap.entries) {
            final key = entry.key?.toString() ?? '';
            final value = entry.value;
            if (key.isNotEmpty) {
              data[key] = value;
            }
          }
        } else {
          debugPrint('❌ Device metadata is not a valid Map structure');
          return null;
        }

        debugPrint(
          '📋 Device metadata retrieved for "$deviceName": ${data.keys.toList()}',
        );
        return data;
      }

      debugPrint('📋 No metadata found for device "$deviceName"');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting device metadata: $e');
      return null;
    }
  }

  /// Safely parse a dynamic value to double, handling both string and numeric formats
  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print('Warning: Unable to parse "$value" as double: $e');
        return null;
      }
    }

    print('Warning: Unexpected GPS coordinate type: ${value.runtimeType}');
    return null;
  }

  /// Extract GPS data from FRDB metadata and convert to Firestore format
  Map<String, double>? _extractGPSDataFromMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return null;

    // Safe type casting for GPS data
    Map<String, dynamic>? gpsData;
    final rawGpsData = metadata['gps'];
    if (rawGpsData is Map) {
      gpsData = <String, dynamic>{};
      for (final entry in rawGpsData.entries) {
        final key = entry.key?.toString() ?? '';
        final value = entry.value;
        if (key.isNotEmpty) {
          gpsData[key] = value;
        }
      }
    }
    if (gpsData != null) {
      final extractedData = <String, double>{};

      // Extract and convert GPS data to double format for Firestore
      // Handle both numeric and string formats from Firebase
      if (gpsData['latitude'] != null) {
        final latitude = _safeParseDouble(gpsData['latitude']);
        if (latitude != null) extractedData['latitude'] = latitude;
      }
      if (gpsData['longitude'] != null) {
        final longitude = _safeParseDouble(gpsData['longitude']);
        if (longitude != null) extractedData['longitude'] = longitude;
      }
      if (gpsData['altitude_m'] != null) {
        final altitude = _safeParseDouble(gpsData['altitude_m']);
        if (altitude != null) extractedData['altitude'] = altitude;
      }
      if (gpsData['speed_kmph'] != null) {
        final speed = _safeParseDouble(gpsData['speed_kmph']);
        if (speed != null) extractedData['speed'] = speed;
      }
      if (gpsData['course_deg'] != null) {
        final heading = _safeParseDouble(gpsData['course_deg']);
        if (heading != null) extractedData['heading'] = heading;
      }

      return extractedData.isNotEmpty ? extractedData : null;
    }
    return null;
  }

  // CRUD Operations
  Future<Device> addDevice({
    required String name,
    String? vehicleId,
    Map<String, double>? gpsData,
    bool isActive = true,
  }) async {
    // Use enhanced validation method
    return await addDeviceWithValidation(
      deviceName: name,
      vehicleId: vehicleId,
      gpsData: gpsData,
      isActive: isActive,
    );
  }

  /// Enhanced add device with complete validation flow
  /// Step 1: Check Firestore uniqueness
  /// Step 2: Check FRDB existence
  /// Step 3: Validate device.name == devices/{deviceId} in FRDB
  /// Step 4: Add to Firestore collection
  Future<Device> addDeviceWithValidation({
    required String deviceName,
    String? vehicleId,
    Map<String, double>? gpsData,
    bool isActive = true,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    debugPrint('🚀 Starting complete device validation for: "$deviceName"');

    // Step 1: Check if device name is unique in Firestore
    final isUniqueInFirestore = await _checkDeviceNameUniqueness(deviceName);
    if (!isUniqueInFirestore) {
      throw Exception(
        'Device name "$deviceName" is already registered to your account. Please choose a different name.',
      );
    }
    debugPrint('✅ Step 1: Device name is unique in Firestore');

    // Step 2: Check if device exists in Firebase Realtime Database
    final existsInRealtimeDB = await _validateDeviceExistsInRealtimeDB(
      deviceName,
    );
    if (!existsInRealtimeDB) {
      throw Exception(
        'Device "$deviceName" not found in GPS system. Please ensure the ESP32 device is online and sending data.',
      );
    }
    debugPrint('✅ Step 2: Device exists in Firebase Realtime Database');

    // Step 3: Validate device name matches FRDB device ID
    final isValidMatch = await _validateDeviceNameMatchesRealtimeDBId(
      deviceName,
    );
    if (!isValidMatch) {
      throw Exception(
        'Device name validation failed. The device ID in GPS system does not match "$deviceName".',
      );
    }
    debugPrint('✅ Step 3: Device name matches FRDB device ID');

    // Step 4: Get device metadata from FRDB for additional GPS data
    final deviceMetadata = await _getDeviceMetadataFromRealtimeDB(deviceName);
    final extractedGpsData = _extractGPSDataFromMetadata(deviceMetadata);

    // Step 5: Create device in Firestore
    final docRef = _firestore.collection('devices').doc();
    final device = Device(
      id: docRef.id,
      name: deviceName,
      ownerId: _currentUserId!,
      vehicleId: vehicleId,
      gpsData: extractedGpsData ?? gpsData ?? {},
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(device.toMap());
    debugPrint(
      '✅ Step 4: Device "$deviceName" successfully added to Firestore',
    );

    return device;
  }

  Future<void> updateDevice(Device device) async {
    // Check if device name is unique (excluding the current device)
    final isUnique = await _checkDeviceNameUniqueness(
      device.name,
      excludeDeviceId: device.id,
    );
    if (!isUnique) {
      throw Exception(
        'Device name "${device.name}" is already in use. Please choose a different name.',
      );
    }

    await _firestore
        .collection('devices')
        .doc(device.id)
        .update(device.copyWith(updatedAt: DateTime.now()).toMap());
  }

  Future<void> deleteDevice(String id) async {
    try {
      // Step 1: Find all vehicles that reference this device
      final vehiclesWithDevice =
          await _firestore
              .collection('vehicles')
              .where('deviceId', isEqualTo: id)
              .get();

      // Step 2: Use batch operation for atomic transaction
      final batch = _firestore.batch();

      // Step 3: Set deviceId to null for all affected vehicles
      for (final vehicleDoc in vehiclesWithDevice.docs) {
        batch.update(vehicleDoc.reference, {
          'deviceId': null,
          'updated_at': firestore.Timestamp.fromDate(DateTime.now()),
        });
      }

      // Step 4: Delete the device
      batch.delete(_firestore.collection('devices').doc(id));

      // Step 5: Commit all changes atomically
      await batch.commit();

      debugPrint(
        '✅ Device "$id" deleted with cascade cleanup of ${vehiclesWithDevice.docs.length} vehicles',
      );
    } catch (e) {
      debugPrint('❌ Error deleting device with cascade: $e');
      throw Exception('Failed to delete device: $e');
    }
  }

  // Status and Assignment Updates
  Future<void> updateDeviceGPS({
    required String deviceId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    double? heading,
  }) => _updateDeviceFields(deviceId, {
    'gpsData': {
      'latitude': latitude,
      'longitude': longitude,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
    },
  });

  Future<void> assignDeviceToVehicle(String deviceId, String vehicleId) async {
    debugPrint('🔧 [DEVICE_SERVICE] assignDeviceToVehicle called');
    debugPrint(
      '🔧 [DEVICE_SERVICE] deviceId: $deviceId, vehicleId: $vehicleId',
    );

    try {
      await _updateDeviceFields(deviceId, {'vehicleId': vehicleId});
      debugPrint('✅ [DEVICE_SERVICE] Device assigned successfully');
    } catch (e) {
      debugPrint('❌ [DEVICE_SERVICE] Error assigning device: $e');
      rethrow;
    }
  }

  Future<void> unassignDeviceFromVehicle(String deviceId) async {
    debugPrint('🔧 [DEVICE_SERVICE] unassignDeviceFromVehicle called');
    debugPrint('🔧 [DEVICE_SERVICE] deviceId: $deviceId');

    try {
      await _updateDeviceFields(deviceId, {'vehicleId': null});
      debugPrint('✅ [DEVICE_SERVICE] Device unassigned successfully');
    } catch (e) {
      debugPrint('❌ [DEVICE_SERVICE] Error unassigning device: $e');
      rethrow;
    }
  }

  Future<void> toggleDeviceStatus(String deviceId, bool isActive) async {
    debugPrint('🔧 [DEVICE_SERVICE] toggleDeviceStatus called');
    debugPrint('🔧 [DEVICE_SERVICE] deviceId: $deviceId, isActive: $isActive');

    try {
      await _updateDeviceFields(deviceId, {'isActive': isActive});
      debugPrint('✅ [DEVICE_SERVICE] Device status toggled successfully');
    } catch (e) {
      debugPrint('❌ [DEVICE_SERVICE] Error toggling device status: $e');
      rethrow;
    }
  }

  // Queries
  Future<Device?> getDeviceById(String id) async {
    final doc = await _firestore.collection('devices').doc(id).get();
    return doc.exists && doc.data() != null
        ? Device.fromMap(doc.data()!, doc.id)
        : null;
  }

  Future<Device?> getDeviceByVehicleId(String vehicleId) async {
    final snapshot =
        await _firestore
            .collection('devices')
            .where('vehicleId', isEqualTo: vehicleId)
            .limit(1)
            .get();
    return snapshot.docs.isNotEmpty
        ? Device.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id)
        : null;
  }

  Future<List<Device>> getUnassignedDevices() =>
      _getUserDevicesWhere((query) => query.where('vehicleId', isNull: true));

  Future<List<Device>> getDevicesWithValidGPS() async {
    final devices = await _getUserDevicesWhere(
      (query) => query.where('isActive', isEqualTo: true),
    );
    return devices.where((device) => device.hasValidGPS).toList();
  }

  /// Get all vehicles that reference a specific device ID
  Future<List<String>> getVehicleIdsByDeviceId(String deviceId) async {
    try {
      final snapshot =
          await _firestore
              .collection('vehicles')
              .where('deviceId', isEqualTo: deviceId)
              .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting vehicles by device ID: $e');
      return [];
    }
  }

  // Batch Operations
  Future<void> batchUpdateDeviceLocations(
    Map<String, Map<String, double>> deviceLocationMap,
  ) async {
    final batch = _firestore.batch();
    final timestamp = firestore.Timestamp.fromDate(DateTime.now());

    for (final entry in deviceLocationMap.entries) {
      batch.update(_firestore.collection('devices').doc(entry.key), {
        'gpsData': entry.value,
        'updated_at': timestamp,
      });
    }
    await batch.commit();
  }

  // Device Validation Public Methods

  /// Check if device exists in Firebase Realtime Database
  /// Returns true if device exists and is sending data
  Future<bool> validateDeviceInRealtimeDB(String deviceName) async {
    return await _validateDeviceExistsInRealtimeDB(deviceName);
  }

  /// Check if device is actively sending data to FRDB
  Future<bool> isDeviceActiveInRealtimeDB(String deviceName) async {
    try {
      final metadata = await _getDeviceMetadataFromRealtimeDB(deviceName);
      if (metadata == null) return false;

      // Safe type casting for GPS data
      Map<String, dynamic>? gpsData;
      final rawGpsData = metadata['gps'];
      if (rawGpsData is Map) {
        gpsData = <String, dynamic>{};
        for (final entry in rawGpsData.entries) {
          final key = entry.key?.toString() ?? '';
          final value = entry.value;
          if (key.isNotEmpty) {
            gpsData[key] = value;
          }
        }
      }

      if (gpsData == null) return false;

      // Check if device has valid coordinates
      final lat = gpsData['latitude'];
      final lng = gpsData['longitude'];

      return lat != null && lng != null && lat != 0 && lng != 0;
    } catch (e) {
      debugPrint('❌ Error checking device activity: $e');
      return false;
    }
  }

  /// Get all available devices from FRDB that are not yet added to user's Firestore
  Future<List<String>> getAvailableDevicesFromRealtimeDB() async {
    try {
      debugPrint('🔍 Getting available devices from FRDB...');

      // Get all devices from FRDB
      final ref = _realtimeDB.ref('devices');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        debugPrint('📋 No devices found in FRDB');
        return [];
      }
      // Safe type casting for Firebase Realtime Database data
      Map<String, dynamic> realtimeDevices;
      if (snapshot.value is Map) {
        final rawMap = snapshot.value as Map;
        realtimeDevices = <String, dynamic>{};

        // Safely convert each key-value pair
        for (final entry in rawMap.entries) {
          final key = entry.key?.toString() ?? '';
          if (key.isNotEmpty) {
            realtimeDevices[key] = entry.value;
          }
        }
      } else {
        debugPrint('❌ FRDB devices data is not a valid Map structure');
        return [];
      }

      final realtimeDeviceNames = realtimeDevices.keys.toList();

      // Get user's devices from Firestore
      final userDevices = await _getUserDevices();
      final firestoreDeviceNames = userDevices.map((d) => d.name).toList();

      // Return devices that exist in FRDB but not in user's Firestore collection
      final availableDevices =
          realtimeDeviceNames
              .where((name) => !firestoreDeviceNames.contains(name))
              .toList();

      debugPrint('📋 Available devices: $availableDevices');
      debugPrint('📋 User already has: $firestoreDeviceNames');

      return availableDevices;
    } catch (e) {
      debugPrint('❌ Error getting available devices: $e');
      return [];
    }
  }

  /// Batch validate multiple device names
  Future<Map<String, DeviceValidationResult>> batchValidateDeviceNames(
    List<String> deviceNames,
  ) async {
    final results = <String, DeviceValidationResult>{};

    for (final deviceName in deviceNames) {
      try {
        // Check Firestore uniqueness
        final isUnique = await _checkDeviceNameUniqueness(deviceName);
        if (!isUnique) {
          results[deviceName] = DeviceValidationResult(
            isValid: false,
            error: 'Device name already exists in your account',
          );
          continue;
        }

        // Check FRDB existence
        final existsInFRDB = await _validateDeviceExistsInRealtimeDB(
          deviceName,
        );
        if (!existsInFRDB) {
          results[deviceName] = DeviceValidationResult(
            isValid: false,
            error: 'Device not found in GPS system',
          );
          continue;
        }

        // Check name matches FRDB ID
        final isValidMatch = await _validateDeviceNameMatchesRealtimeDBId(
          deviceName,
        );
        if (!isValidMatch) {
          results[deviceName] = DeviceValidationResult(
            isValid: false,
            error: 'Device name does not match GPS system ID',
          );
          continue;
        }

        results[deviceName] = DeviceValidationResult(isValid: true);
      } catch (e) {
        results[deviceName] = DeviceValidationResult(
          isValid: false,
          error: 'Validation error: $e',
        );
      }
    }

    return results;
  }

  /// Get real-time device status from FRDB
  Stream<Map<String, dynamic>?> getDeviceRealtimeStatus(String deviceName) {
    final ref = _realtimeDB.ref('devices/$deviceName');
    return ref.onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        // Safe type casting for Firebase Realtime Database data
        if (event.snapshot.value is Map) {
          final rawMap = event.snapshot.value as Map;
          final data = <String, dynamic>{};

          // Safely convert each key-value pair
          for (final entry in rawMap.entries) {
            final key = entry.key?.toString() ?? '';
            final value = entry.value;
            if (key.isNotEmpty) {
              data[key] = value;
            }
          }
          return data;
        }
      }
      return null;
    });
  }

  // Bridge Methods for Realtime Database Integration
  Future<String?> getCurrentUserPrimaryDeviceId() async {
    if (_currentUserId == null) return null;

    try {
      final devices = await _getUserDevices();
      if (devices.isEmpty) return null;

      // Priority: Active with GPS > Active > Any
      return devices
              .where((d) => d.isActive && d.hasValidGPS)
              .firstOrNull
              ?.id ??
          devices.where((d) => d.isActive).firstOrNull?.id ??
          devices.first.id;
    } catch (e) {
      throw Exception('Failed to get primary device: $e');
    }
  }

  Future<String?> getDeviceNameById(String deviceId) async {
    try {
      return (await getDeviceById(deviceId))?.name;
    } catch (e) {
      return null;
    }
  }

  Future<Device?> getDeviceByMacId(String macId) async {
    if (_currentUserId == null) return null;

    try {
      final snapshot =
          await _firestore
              .collection('devices')
              .where('ownerId', isEqualTo: _currentUserId)
              .where('name', isEqualTo: macId)
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty
          ? Device.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id)
          : null;
    } catch (e) {
      debugPrint('Error getting device by MAC ID: $e');
      return null;
    }
  }

  Future<String?> getValidatedDeviceMacIdForMap() async {
    try {
      final primaryDeviceId = await getCurrentUserPrimaryDeviceId();
      if (primaryDeviceId == null) return null;

      final device = await getDeviceById(primaryDeviceId);
      if (device?.ownerId != _currentUserId) return null;

      final macId = device!.name;
      final isValid = await _validateDeviceInRealtimeDB(macId);

      if (isValid) {
        debugPrint('Bridge: Successfully validated MAC ID $macId');
        return macId;
      } else {
        debugPrint('Bridge: MAC ID $macId not found in FRDB');
        return null;
      }
    } catch (e) {
      debugPrint('Error in bridge validation: $e');
      return null;
    }
  }

  // Stream version of validated MAC ID
  Stream<String?> getValidatedDeviceMacIdStream() =>
      getCurrentUserPrimaryDeviceIdStream().asyncMap((deviceId) async {
        if (deviceId == null) return null;
        final device = await getDeviceById(deviceId);
        if (device?.ownerId != _currentUserId) return null;
        final isValid = await _validateDeviceInRealtimeDB(device!.name);
        return isValid ? device.name : null;
      });

  Stream<String?> getCurrentUserPrimaryDeviceIdStream() {
    if (_currentUserId == null) return Stream.value(null);

    return _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final devices = _docsToDevices(snapshot);

          return devices
                  .where((d) => d.isActive && d.hasValidGPS)
                  .firstOrNull
                  ?.id ??
              devices.where((d) => d.isActive).firstOrNull?.id ??
              devices.first.id;
        });
  }

  // Private Helper Methods
  List<Device> _docsToDevices(firestore.QuerySnapshot snapshot) =>
      snapshot.docs
          .map(
            (doc) => Device.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

  Future<void> _updateDeviceFields(
    String deviceId,
    Map<String, dynamic> fields,
  ) async {
    debugPrint(
      '🔧 [DEVICE_UPDATE] Updating device $deviceId with fields: $fields',
    );

    try {
      await _firestore.collection('devices').doc(deviceId).update({
        ...fields,
        'updated_at': firestore.Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('✅ [DEVICE_UPDATE] Device fields updated successfully');
    } catch (e) {
      debugPrint('❌ [DEVICE_UPDATE] Error updating device fields: $e');
      rethrow;
    }
  }

  Future<List<Device>> _getUserDevices() async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    final snapshot =
        await _firestore
            .collection('devices')
            .where('ownerId', isEqualTo: _currentUserId)
            .get();
    return _docsToDevices(snapshot);
  }

  Future<List<Device>> _getUserDevicesWhere(
    firestore.Query<Map<String, dynamic>> Function(
      firestore.Query<Map<String, dynamic>>,
    )
    whereClause,
  ) async {
    if (_currentUserId == null) throw Exception('User not authenticated');
    final query = _firestore
        .collection('devices')
        .where('ownerId', isEqualTo: _currentUserId);
    final snapshot = await whereClause(query).get();
    return _docsToDevices(snapshot);
  }

  Future<bool> _validateDeviceInRealtimeDB(String deviceMacId) async {
    try {
      final snapshot = await _realtimeDB.ref('devices/$deviceMacId').get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('Error validating device in FRDB: $e');
      return false;
    }
  }

  /// Check if user has any devices
  Future<bool> userHasDevices() async {
    try {
      final devices = await _getUserDevices();
      return devices.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking user devices: $e');
      return false;
    }
  }

  /// Get device initialization data for map with FRDB validation
  Future<DeviceMapData?> getDeviceForMapInitialization() async {
    try {
      debugPrint('🚀 Getting device for map initialization...');

      // Get user's primary device
      final primaryDeviceId = await getCurrentUserPrimaryDeviceId();
      if (primaryDeviceId == null) {
        debugPrint('❌ No primary device found');
        return null;
      }

      final device = await getDeviceById(primaryDeviceId);
      if (device == null) {
        debugPrint('❌ Primary device not found in Firestore');
        return null;
      }

      // Validate device exists in FRDB
      final existsInFRDB = await _validateDeviceExistsInRealtimeDB(device.name);
      if (!existsInFRDB) {
        debugPrint('❌ Device ${device.name} not found in FRDB');
        return null;
      }

      // Get real-time GPS data from FRDB
      final realtimeData = await _getDeviceMetadataFromRealtimeDB(device.name);
      final gpsData = realtimeData?['gps'] as Map<String, dynamic>?;

      debugPrint('✅ Device for map initialization: ${device.name}');

      return DeviceMapData(
        device: device,
        realtimeGPS: gpsData,
        hasRealtimeData: realtimeData != null,
      );
    } catch (e) {
      debugPrint('❌ Error getting device for map: $e');
      return null;
    }
  }
}

/// Device map data class for map initialization
class DeviceMapData {
  final Device device;
  final Map<String, dynamic>? realtimeGPS;
  final bool hasRealtimeData;

  DeviceMapData({
    required this.device,
    this.realtimeGPS,
    this.hasRealtimeData = false,
  });

  /// Use device.name as deviceId for map services
  String get deviceId => device.name; // MAC address
  String get deviceName => device.name;

  /// Extract GPS coordinates from realtime data or fallback to device data
  double? get latitude {
    if (realtimeGPS != null) {
      final lat = realtimeGPS!['latitude'];
      if (lat != null && lat != 0) return (lat as num).toDouble();
    }
    return device.gpsData?['latitude'];
  }

  double? get longitude {
    if (realtimeGPS != null) {
      final lng = realtimeGPS!['longitude'];
      if (lng != null && lng != 0) return (lng as num).toDouble();
    }
    return device.gpsData?['longitude'];
  }

  /// Check if device has valid GPS coordinates
  bool get hasValidGPS => lat != null && lng != null && lat != 0 && lng != 0;

  /// Get latitude (alias for consistency)
  double? get lat => latitude;

  /// Get longitude (alias for consistency)
  double? get lng => longitude;

  /// Extract additional GPS data
  double? get altitude {
    if (realtimeGPS != null) {
      final alt = realtimeGPS!['altitude_m'];
      if (alt != null) return (alt as num).toDouble();
    }
    return device.gpsData?['altitude'];
  }

  double? get speed {
    if (realtimeGPS != null) {
      final spd = realtimeGPS!['speed_kmph'];
      if (spd != null) return (spd as num).toDouble();
    }
    return device.gpsData?['speed'];
  }

  double? get heading {
    if (realtimeGPS != null) {
      final hdg = realtimeGPS!['course_deg'];
      if (hdg != null) return (hdg as num).toDouble();
    }
    return device.gpsData?['heading'];
  }

  @override
  String toString() {
    return 'DeviceMapData(deviceId: $deviceId, hasValidGPS: $hasValidGPS, hasRealtimeData: $hasRealtimeData)';
  }
}

/// Device validation result class
class DeviceValidationResult {
  final bool isValid;
  final String? error;
  final Map<String, dynamic>? metadata;

  DeviceValidationResult({required this.isValid, this.error, this.metadata});

  @override
  String toString() {
    return 'DeviceValidationResult(isValid: $isValid, error: $error)';
  }
}

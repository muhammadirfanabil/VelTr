import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as database;
import 'package:flutter/foundation.dart';
import '../../models/Device/device.dart';

class DeviceService {
  final firestore.FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DeviceService({
    firestore.FirebaseFirestore? firestoreInstance,
    FirebaseAuth? auth,
  }) : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

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

  Stream<Device> getDeviceStream(String deviceId) => _firestore
      .collection('devices')
      .doc(deviceId)
      .snapshots()
      .map((doc) => Device.fromMap(doc.data()!, doc.id));

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

  // CRUD Operations
  Future<Device> addDevice({
    required String name,
    String? vehicleId,
    Map<String, double>? gpsData,
    bool isActive = true,
  }) async {
    if (_currentUserId == null) throw Exception('User not authenticated');

    final docRef = _firestore.collection('devices').doc();
    final device = Device(
      id: docRef.id,
      name: name,
      ownerId: _currentUserId!,
      vehicleId: vehicleId,
      gpsData: gpsData ?? {},
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(device.toMap());
    return device;
  }

  Future<void> updateDevice(Device device) => _firestore
      .collection('devices')
      .doc(device.id)
      .update(device.copyWith(updatedAt: DateTime.now()).toMap());

  Future<void> deleteDevice(String id) =>
      _firestore.collection('devices').doc(id).delete();

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

  Future<void> assignDeviceToVehicle(String deviceId, String vehicleId) =>
      _updateDeviceFields(deviceId, {'vehicleId': vehicleId});

  Future<void> unassignDeviceFromVehicle(String deviceId) =>
      _updateDeviceFields(deviceId, {'vehicleId': null});

  Future<void> toggleDeviceStatus(String deviceId, bool isActive) =>
      _updateDeviceFields(deviceId, {'isActive': isActive});

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
  ) => _firestore.collection('devices').doc(deviceId).update({
    ...fields,
    'updated_at': firestore.Timestamp.fromDate(DateTime.now()),
  });

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
      final snapshot =
          await database.FirebaseDatabase.instance
              .ref('devices/$deviceMacId')
              .get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('Error validating device in FRDB: $e');
      return false;
    }
  }
}

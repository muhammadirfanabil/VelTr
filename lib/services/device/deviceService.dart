import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
}

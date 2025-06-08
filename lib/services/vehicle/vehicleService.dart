import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/vehicle/vehicle.dart';

/// Service class for handling vehicle-related operations
class VehicleService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a new VehicleService instance
  VehicleService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Returns a stream of vehicles for the current user
  Stream<List<vehicle>> getVehiclesStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    return _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: currentUser.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => vehicle.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Adds a new vehicle for the current user
  Future<vehicle> addVehicle({
    required String name,
    String? vehicleTypes,
    String? plateNumber,
    String? deviceId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _firestore.collection('vehicles').doc();
    final newVehicle = vehicle(
      id: docRef.id,
      name: name,
      ownerId: currentUser.uid,
      deviceId: deviceId,
      vehicleTypes: vehicleTypes,
      plateNumber: plateNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final data = newVehicle.toMap();
    print('Saving vehicle with data: $data');

    await docRef.set(newVehicle.toMap());
    return newVehicle;
  }

  /// Updates an existing vehicle
  Future<void> updateVehicle(vehicle vehicleToUpdate) async {
    await _firestore
        .collection('vehicles')
        .doc(vehicleToUpdate.id)
        .update(vehicleToUpdate.copyWith(updatedAt: DateTime.now()).toMap());
  }

  /// Attach device to vehicle
  Future<void> attachDeviceToVehicle(String vehicleId, String deviceId) async {
    await _firestore.collection('vehicles').doc(vehicleId).update({
      'deviceId': deviceId,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Detach device from vehicle
  Future<void> detachDeviceFromVehicle(String vehicleId) async {
    await _firestore.collection('vehicles').doc(vehicleId).update({
      'deviceId': null,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Deletes a vehicle
  Future<void> deleteVehicle(String id) async {
    await _firestore.collection('vehicles').doc(id).delete();
  }

  /// Gets a single vehicle by ID
  Future<vehicle?> getVehicleById(String id) async {
    final doc = await _firestore.collection('vehicles').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return vehicle.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get vehicles that have no assigned device
  Future<List<vehicle>> getVehiclesWithoutDevice() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot =
        await _firestore
            .collection('vehicles')
            .where('ownerId', isEqualTo: currentUser.uid)
            .where('deviceId', isNull: true)
            .get();

    return snapshot.docs
        .map((doc) => vehicle.fromMap(doc.data(), doc.id))
        .toList();
  }
}

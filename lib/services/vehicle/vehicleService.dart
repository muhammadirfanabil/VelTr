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

  Future<bool> verifyDeviceAvailability(String deviceId) async {
    final deviceDoc =
        await _firestore.collection('devices').doc(deviceId).get();
    return deviceDoc.exists;
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
  Future<void> detachDeviceFromVehicle(String deviceId) async {
    try {
      // First, find the vehicle that has this device
      final vehicleQuery =
          await _firestore
              .collection('vehicles')
              .where('deviceId', isEqualTo: deviceId)
              .get();

      if (vehicleQuery.docs.isNotEmpty) {
        final vehicleDoc = vehicleQuery.docs.first;

        // Start a batch write
        final batch = _firestore.batch();

        // Update vehicle document
        batch.update(vehicleDoc.reference, {
          'deviceId': null,
          'updated_at': Timestamp.fromDate(DateTime.now()),
        });

        // Check if device document exists before trying to update it
        final deviceDoc =
            await _firestore.collection('devices').doc(deviceId).get();
        if (deviceDoc.exists) {
          // Only update device if it exists
          batch.update(deviceDoc.reference, {
            'vehicleId': null,
            'updated_at': Timestamp.fromDate(DateTime.now()),
          });
        }

        // Commit the updates
        await batch.commit();
      }
    } catch (e) {
      print('Error detaching device: $e');
      // Don't throw an error if it's just because the device doesn't exist
      if (!e.toString().contains('NOT_FOUND')) {
        throw Exception('Failed to detach device: $e');
      }
    }
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

  Future<void> assignDevice(String deviceId, String vehicleId) async {
    // Start a batch write
    final batch = _firestore.batch();

    // Update vehicle with device ID
    final vehicleRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(vehicleRef, {
      'deviceId': deviceId,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });

    // Update device with vehicle ID
    final deviceRef = _firestore.collection('devices').doc(deviceId);
    batch.update(deviceRef, {
      'vehicleId': vehicleId,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Commit the batch
    await batch.commit();
  }

  Future<void> unassignDevice(String deviceId, String vehicleId) async {
    // Start a batch write
    final batch = _firestore.batch();

    // Remove device ID from vehicle
    final vehicleRef = _firestore.collection('vehicles').doc(vehicleId);
    batch.update(vehicleRef, {
      'deviceId': null,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });

    // Remove vehicle ID from device
    final deviceRef = _firestore.collection('devices').doc(deviceId);
    batch.update(deviceRef, {
      'vehicleId': null,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Commit the batch
    await batch.commit();
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

  /// Updates vehicle information without modifying deviceId
  /// This is used when device assignment is handled separately to avoid conflicts
  Future<void> updateVehicleInfoOnly(vehicle vehicleToUpdate) async {
    final updateData =
        vehicleToUpdate.copyWith(updatedAt: DateTime.now()).toMap();
    // Remove deviceId from update to avoid conflicts with separate device assignment operations
    updateData.remove('deviceId');

    await _firestore
        .collection('vehicles')
        .doc(vehicleToUpdate.id)
        .update(updateData);
  }
}

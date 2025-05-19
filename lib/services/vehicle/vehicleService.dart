import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/Vehicle/vehicle.dart';

/// Service class for handling vehicle-related operations
class vehicleService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates a new VehicleService instance
  vehicleService({FirebaseFirestore? firestore, FirebaseAuth? auth})
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
        .where('user_id', isEqualTo: currentUser.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => vehicle.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Adds a new vehicle for the current user
  Future<void> addVehicle({
    required String name,
    required String vehicleTypes,
    required String plateNumber,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    await _firestore.collection('vehicles').add({
      'name': name,
      'vehicle_types': vehicleTypes,
      'plate_number': plateNumber,
      'user_id': currentUser.uid,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
    });
  }

  /// Updates an existing vehicle
  Future<void> updateVehicle({
    required String id,
    required String name,
    required String vehicleTypes,
    required String plateNumber,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('vehicles').doc(id).update({
      'name': name,
      'vehicle_types': vehicleTypes,
      'plate_number': plateNumber,
      'updated_at': Timestamp.fromDate(now),
    });
  }

  /// Deletes a vehicle
  Future<void> deleteVehicle(String id) async {
    await _firestore.collection('vehicles').doc(id).delete();
  }

  /// Gets a single vehicle by ID
  Future<vehicle?> getVehicleById(String id) async {
    final doc = await _firestore.collection('vehicles').doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return vehicle.fromMap(doc.data()!, doc.id);
  }
}

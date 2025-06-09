import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/Geofence/Geofence.dart';

class GeofenceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GeofenceService({FirebaseFirestore? firestoreInstance, FirebaseAuth? auth})
    : _firestore = firestoreInstance ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;
  /// Get all geofences for a specific device (filtered by current user)
  Stream<List<Geofence>> getGeofencesStream(String deviceId) {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('geofences')
        .where('deviceId', isEqualTo: deviceId)
        .where('ownerId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Geofence.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }
  /// Get a single geofence by ID (with ownership verification)
  Future<Geofence?> getGeofenceById(String geofenceId) async {
    if (_currentUserId == null) return null;

    try {
      final doc =
          await _firestore.collection('geofences').doc(geofenceId).get();
      if (doc.exists && doc.data() != null) {
        final geofence = Geofence.fromMap(doc.data()!, doc.id);
        // Verify ownership
        if (geofence.ownerId == _currentUserId) {
          return geofence;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting geofence by ID: $e');
      return null;
    }
  }

  /// Create a new geofence
  Future<String> createGeofence(Geofence geofence) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (!geofence.isValid) {
      throw Exception('Geofence must have at least 3 points');
    }    try {
      // Generate address if not provided
      String? address = geofence.address;
      if (address == null || address.isEmpty) {
        final centerPoint = geofence.centerPoint;
        address = await _getAddressFromLatLng(
          centerPoint.latitude,
          centerPoint.longitude,
        );
      }

      // Create geofence data for Firestore
      final geofenceData = {
        'deviceId': geofence.deviceId,
        'ownerId': _currentUserId,
        'name': geofence.name,
        'address': address,
        'points':
            geofence.points
                .map(
                  (point) => {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                  },
                )
                .toList(),
        'status': geofence.status,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('geofences').add(geofenceData);
      debugPrint('Geofence created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating geofence: $e');
      throw Exception('Failed to create geofence: $e');
    }
  }
  /// Update an existing geofence (with ownership verification)
  Future<void> updateGeofence(Geofence geofence) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (!geofence.isValid) {
      throw Exception('Geofence must have at least 3 points');
    }

    // Verify ownership before update
    if (geofence.ownerId != _currentUserId) {
      throw Exception('Unauthorized: Cannot update geofence owned by another user');
    }

    try {
      // Generate address if needed
      String? address = geofence.address;
      if (address == null || address.isEmpty) {
        final centerPoint = geofence.centerPoint;
        address = await _getAddressFromLatLng(
          centerPoint.latitude,
          centerPoint.longitude,
        );
      }

      // Update geofence data
      final updateData = {
        'name': geofence.name,
        'address': address,
        'points':
            geofence.points
                .map(
                  (point) => {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                  },
                )
                .toList(),
        'status': geofence.status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('geofences')
          .doc(geofence.id)
          .update(updateData);

      debugPrint('Geofence updated: ${geofence.id}');
    } catch (e) {
      debugPrint('Error updating geofence: $e');
      throw Exception('Failed to update geofence: $e');
    }
  }
  /// Delete a geofence (with ownership verification)
  Future<void> deleteGeofence(String geofenceId) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Verify ownership before deletion
      final geofence = await getGeofenceById(geofenceId);
      if (geofence == null) {
        throw Exception('Geofence not found or access denied');
      }

      await _firestore.collection('geofences').doc(geofenceId).delete();
      debugPrint('Geofence deleted: $geofenceId');
    } catch (e) {
      debugPrint('Error deleting geofence: $e');
      throw Exception('Failed to delete geofence: $e');
    }
  }

  /// Toggle geofence status (active/inactive) with ownership verification
  Future<void> toggleGeofenceStatus(String geofenceId, bool status) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Verify ownership before status change
      final geofence = await getGeofenceById(geofenceId);
      if (geofence == null) {
        throw Exception('Geofence not found or access denied');
      }

      await _firestore.collection('geofences').doc(geofenceId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Geofence status updated: $geofenceId -> $status');
    } catch (e) {
      debugPrint('Error toggling geofence status: $e');
      throw Exception('Failed to update geofence status: $e');
    }
  }

  /// Get all geofences for the current user (across all devices)
  Stream<List<Geofence>> getAllUserGeofencesStream() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('geofences')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Geofence.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Get active geofences for a device
  Stream<List<Geofence>> getActiveGeofencesStream(String deviceId) {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('geofences')
        .where('deviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Geofence.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Check if a geofence name already exists for a device
  Future<bool> isGeofenceNameUnique(
    String deviceId,
    String name, {
    String? excludeId,
  }) async {
    try {
      Query query = _firestore
          .collection('geofences')
          .where('deviceId', isEqualTo: deviceId)
          .where('name', isEqualTo: name);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return true;

      // If we're updating an existing geofence, exclude it from the check
      if (excludeId != null) {
        return snapshot.docs.every((doc) => doc.id == excludeId);
      }

      return false;
    } catch (e) {
      debugPrint('Error checking geofence name uniqueness: $e');
      return false;
    }
  }

  /// Get geofence statistics for a device
  Future<Map<String, int>> getGeofenceStats(String deviceId) async {
    try {
      final snapshot =
          await _firestore
              .collection('geofences')
              .where('deviceId', isEqualTo: deviceId)
              .get();

      int total = snapshot.docs.length;
      int active =
          snapshot.docs.where((doc) => doc.data()['status'] == true).length;
      int inactive = total - active;

      return {'total': total, 'active': active, 'inactive': inactive};
    } catch (e) {
      debugPrint('Error getting geofence stats: $e');
      return {'total': 0, 'active': 0, 'inactive': 0};
    }
  }

  /// Batch update multiple geofences
  Future<void> batchUpdateGeofences(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final batch = _firestore.batch();

      for (final entry in updates.entries) {
        final geofenceId = entry.key;
        final updateData = entry.value;
        updateData['updatedAt'] = FieldValue.serverTimestamp();

        final docRef = _firestore.collection('geofences').doc(geofenceId);
        batch.update(docRef, updateData);
      }

      await batch.commit();
      debugPrint('Batch update completed for ${updates.length} geofences');
    } catch (e) {
      debugPrint('Error in batch update: $e');
      throw Exception('Failed to update geofences: $e');
    }
  }

  /// Calculate center point from a list of coordinates
  GeofencePoint calculateCenterPoint(List<GeofencePoint> points) {
    if (points.isEmpty) return GeofencePoint(latitude: 0, longitude: 0);

    double totalLat = 0;
    double totalLng = 0;

    for (final point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    return GeofencePoint(
      latitude: totalLat / points.length,
      longitude: totalLng / points.length,
    );
  }

  /// Get address from latitude and longitude coordinates
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((element) => element?.isNotEmpty == true).join(', ');
      }
      return "Address not found";
    } catch (e) {
      debugPrint('Error getting address: $e');
      return "Unknown location";
    }
  }

  /// Validate geofence data before saving
  String? validateGeofence(Geofence geofence) {
    if (geofence.name.trim().isEmpty) {
      return 'Geofence name cannot be empty';
    }

    if (geofence.name.trim().length < 3) {
      return 'Geofence name must be at least 3 characters';
    }

    if (geofence.deviceId.trim().isEmpty) {
      return 'Device ID is required';
    }

    if (!geofence.isValid) {
      return 'At least 3 points are required for a geofence';
    }

    // Check for duplicate points
    final uniquePoints = geofence.points.toSet();
    if (uniquePoints.length != geofence.points.length) {
      return 'Duplicate points are not allowed';
    }

    return null; // Valid
  }

  /// Bulk delete multiple geofences
  Future<void> bulkDeleteGeofences(List<String> geofenceIds) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    if (geofenceIds.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final geofenceId in geofenceIds) {
        final docRef = _firestore.collection('geofences').doc(geofenceId);
        batch.delete(docRef);
      }

      await batch.commit();
      debugPrint('Bulk deleted ${geofenceIds.length} geofences');
    } catch (e) {
      debugPrint('Error in bulk delete: $e');
      throw Exception('Failed to delete geofences: $e');
    }
  }

  /// Search geofences by name
  Future<List<Geofence>> searchGeofencesByName(
    String deviceId,
    String searchTerm,
  ) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot =
          await _firestore
              .collection('geofences')
              .where('deviceId', isEqualTo: deviceId)
              .get();

      final allGeofences =
          snapshot.docs
              .map((doc) => Geofence.fromMap(doc.data(), doc.id))
              .toList();

      // Filter by search term (case-insensitive)
      final searchTermLower = searchTerm.toLowerCase();
      return allGeofences
          .where(
            (geofence) =>
                geofence.name.toLowerCase().contains(searchTermLower) ||
                (geofence.address?.toLowerCase().contains(searchTermLower) ??
                    false),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching geofences: $e');
      return [];
    }
  }

  /// Get geofences count for a device
  Future<int> getGeofencesCount(String deviceId) async {
    try {
      final snapshot =
          await _firestore
              .collection('geofences')
              .where('deviceId', isEqualTo: deviceId)
              .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting geofences count: $e');
      return 0;
    }
  }

  /// Duplicate a geofence with a new name
  Future<String> duplicateGeofence(String geofenceId, String newName) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the original geofence
      final originalGeofence = await getGeofenceById(geofenceId);
      if (originalGeofence == null) {
        throw Exception('Original geofence not found');
      }

      // Create a new geofence with the same data but different name
      final duplicatedGeofence = originalGeofence.copyWith(
        id: '', // Will be set by Firestore
        name: newName,
        status: false, // Start as inactive
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createGeofence(duplicatedGeofence);
    } catch (e) {
      debugPrint('Error duplicating geofence: $e');
      throw Exception('Failed to duplicate geofence: $e');
    }
  }

  /// Get recently created geofences (last 7 days)
  Stream<List<Geofence>> getRecentGeofencesStream(String deviceId) {
    if (_currentUserId == null) return Stream.value([]);

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return _firestore
        .collection('geofences')
        .where('deviceId', isEqualTo: deviceId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Geofence.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Archive/Unarchive a geofence (soft delete)
  Future<void> archiveGeofence(String geofenceId, bool isArchived) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore.collection('geofences').doc(geofenceId).update({
        'isArchived': isArchived,
        'archivedAt': isArchived ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'Geofence ${isArchived ? 'archived' : 'unarchived'}: $geofenceId',
      );
    } catch (e) {
      debugPrint('Error archiving geofence: $e');
      throw Exception(
        'Failed to ${isArchived ? 'archive' : 'unarchive'} geofence: $e',
      );
    }
  }

  /// Get archived geofences
  Stream<List<Geofence>> getArchivedGeofencesStream(String deviceId) {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('geofences')
        .where('deviceId', isEqualTo: deviceId)
        .where('isArchived', isEqualTo: true)
        .orderBy('archivedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Geofence.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a GPS device entity with its properties and database interactions.
class Device {
  final String id;
  final String name; // Human-readable name for the device
  final String? ownerId; // Reference to user ID (can be null if unassigned)
  final String?
  vehicleId; // Reference to vehicle ID (can be null if unattached)
  final Map<String, dynamic>? gpsData; // Current GPS data
  final bool isActive; // Whether the device is currently active
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a new Device instance.
  const Device({
    required this.id,
    required this.name,
    this.ownerId,
    this.vehicleId,
    this.gpsData,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a Device instance from Firestore data.
  factory Device.fromMap(Map<String, dynamic> data, String documentId) {
    return Device(
      id: documentId,
      name: data['name'] ?? 'Device $documentId',
      ownerId: data['ownerId'] ?? data['owner'],
      vehicleId: data['vehicleId'] ?? data['vehicle'],
      gpsData: data['gpsData'] as Map<String, dynamic>?,
      isActive: data['isActive'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this Device to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'vehicleId': vehicleId,
      'gpsData': gpsData,
      'isActive': isActive,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a copy with modified fields.
  Device copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? vehicleId,
    Map<String, dynamic>? gpsData,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      vehicleId: vehicleId ?? this.vehicleId,
      gpsData: gpsData ?? this.gpsData,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if device has valid GPS data
  bool get hasValidGPS {
    if (gpsData == null) return false;
    final lat = gpsData!['latitude'];
    final lon = gpsData!['longitude'];
    return lat != null && lon != null && lat != 0 && lon != 0;
  }

  /// Get formatted GPS coordinates
  String get coordinatesString {
    if (!hasValidGPS) return 'No GPS data';
    final lat = gpsData!['latitude'];
    final lon = gpsData!['longitude'];
    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lon.toStringAsFixed(5)}';
  }

  @override
  String toString() =>
      'Device(id: $id, name: $name, ownerId: $ownerId, vehicleId: $vehicleId, isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          other.id == id &&
          other.name == name &&
          other.ownerId == ownerId &&
          other.vehicleId == vehicleId &&
          other.isActive == isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      ownerId.hashCode ^
      vehicleId.hashCode ^
      isActive.hashCode;
}

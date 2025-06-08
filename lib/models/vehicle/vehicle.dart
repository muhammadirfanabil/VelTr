import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a vehicle entity with its properties and database interactions.
class vehicle {
  final String id;
  final String name;
  final String ownerId; // Reference to user ID
  final String? deviceId; // Can be null if no device is attached
  final String? vehicleTypes; // Optional: type of vehicle
  final String? plateNumber; // Optional: license plate
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a new vehicle instance.
  const vehicle({
    required this.id,
    required this.name,
    required this.ownerId,
    this.deviceId,
    this.vehicleTypes,
    this.plateNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a vehicle instance from Firestore data.
  factory vehicle.fromMap(Map<String, dynamic> data, String documentId) {
    return vehicle(
      id: documentId,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? data['owner'] ?? '',
      deviceId: data['deviceId'],
      vehicleTypes: data['vehicle_types'] ?? data['vehicleTypes'],
      plateNumber: data['plate_number'] ?? data['plateNumber'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this vehicle to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'deviceId': deviceId,
      'vehicle_types': vehicleTypes,
      'plate_number': plateNumber,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a copy with modified fields.
  vehicle copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? deviceId,
    String? vehicleTypes,
    String? plateNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      deviceId: deviceId ?? this.deviceId,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      plateNumber: plateNumber ?? this.plateNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'vehicle(id: $id, name: $name, ownerId: $ownerId, deviceId: $deviceId, vehicleTypes: $vehicleTypes, plateNumber: $plateNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is vehicle &&
          other.id == id &&
          other.name == name &&
          other.ownerId == ownerId &&
          other.deviceId == deviceId &&
          other.vehicleTypes == vehicleTypes &&
          other.plateNumber == plateNumber;

  @override
  int get hashCode => Object.hash(id, name, vehicleTypes, plateNumber);
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a vehicle entity with its properties and database interactions.
class vehicle {
  final String id;
  final String name;
  final String vehicleTypes;
  final String plateNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a new vehicle instance.
  const vehicle({
    required this.id,
    required this.name,
    required this.vehicleTypes,
    required this.plateNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a vehicle instance from Firestore data.
  factory vehicle.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return vehicle(
      id: documentId,
      name: data['name'] ?? '',
      vehicleTypes: data['vehicle_types'] ?? '',
      plateNumber: data['plate_number'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this vehicle to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
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
    String? vehicleTypes,
    String? plateNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      plateNumber: plateNumber ?? this.plateNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'vehicle(id: $id, name: $name, vehicleTypes: $vehicleTypes, plateNumber: $plateNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is vehicle &&
          other.id == id &&
          other.name == name &&
          other.vehicleTypes == vehicleTypes &&
          other.plateNumber == plateNumber;

  @override
  int get hashCode => Object.hash(id, name, vehicleTypes, plateNumber);
}

import 'package:cloud_firestore/cloud_firestore.dart';

class GeofencePoint {
  final double latitude;
  final double longitude;

  const GeofencePoint({required this.latitude, required this.longitude});
  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  factory GeofencePoint.fromMap(Map<String, dynamic> map) {
    return GeofencePoint(
      latitude: (map['latitude'] ?? map['lat'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? map['lng'] ?? 0.0).toDouble(),
    );
  }

  factory GeofencePoint.fromJson(Map<String, dynamic> json) {
    return GeofencePoint(
      latitude: (json['latitude'] ?? json['lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'GeofencePoint(latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeofencePoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class Geofence {
  final String id;
  final String deviceId;
  final String ownerId;
  final String name;
  final String? address;
  final List<GeofencePoint> points;
  final bool status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Geofence({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.name,
    this.address,
    required this.points,
    this.status = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a Geofence instance from Firestore data
  factory Geofence.fromMap(Map<String, dynamic> data, String documentId) {
    return Geofence(
      id: documentId,
      deviceId: data['deviceId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      address: data['address'],
      points:
          List<Map<String, dynamic>>.from(
            data['points'] ?? [],
          ).map((point) => GeofencePoint.fromMap(point)).toList(),
      status: data['status'] ?? true,
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: _timestampToDateTime(data['updatedAt']),
    );
  }

  /// Creates a Geofence instance from JSON data
  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? '',
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      points:
          List<Map<String, dynamic>>.from(
            json['points'] ?? [],
          ).map((point) => GeofencePoint.fromMap(point)).toList(),
      status: json['status'] ?? true,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  /// Converts Geofence instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'points': points.map((point) => point.toMap()).toList(),
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Converts Geofence instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'points': points.map((point) => point.toMap()).toList(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy of this geofence with updated fields
  Geofence copyWith({
    String? id,
    String? deviceId,
    String? ownerId,
    String? name,
    String? address,
    List<GeofencePoint>? points,
    bool? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Geofence(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      points: points ?? this.points,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if the geofence has valid points (at least 3 points for a polygon)
  bool get isValid => points.length >= 3;

  /// Calculate the center point of the geofence
  GeofencePoint get centerPoint {
    if (points.isEmpty) return const GeofencePoint(latitude: 0, longitude: 0);

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

  @override
  String toString() {
    return 'Geofence(id: $id, name: $name, deviceId: $deviceId, ownerId: $ownerId, points: ${points.length}, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Geofence &&
        other.id == id &&
        other.deviceId == deviceId &&
        other.ownerId == ownerId &&
        other.name == name &&
        other.address == address &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        deviceId.hashCode ^
        ownerId.hashCode ^
        name.hashCode ^
        address.hashCode ^
        status.hashCode;
  }

  /// Helper method to convert various timestamp formats to DateTime
  static DateTime _timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }
}

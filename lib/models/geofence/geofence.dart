import 'package:cloud_firestore/cloud_firestore.dart';

class GeofencePoint {
  final double latitude;
  final double longitude;

  GeofencePoint({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory GeofencePoint.fromMap(Map<String, dynamic> map) {
    return GeofencePoint(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
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
  final String? geofenceId;
  final String name;
  final String address;
  final DateTime createdAt;
  final String deviceId;
  final String ownerId;
  final Map<int, GeofencePoint> points;
  final bool status;

  Geofence({
    this.geofenceId,
    required this.name,
    required this.address,
    required this.createdAt,
    required this.deviceId,
    required this.ownerId,
    required this.points,
    this.status = true,
  });

  // Create a copy with updated fields
  Geofence copyWith({
    String? geofenceId,
    String? name,
    String? address,
    DateTime? createdAt,
    String? deviceId,
    String? ownerId,
    Map<int, GeofencePoint>? points,
    bool? status,
  }) {
    return Geofence(
      geofenceId: geofenceId ?? this.geofenceId,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      deviceId: deviceId ?? this.deviceId,
      ownerId: ownerId ?? this.ownerId,
      points: points ?? this.points,
      status: status ?? this.status,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    Map<String, dynamic> pointsMap = {};
    points.forEach((key, value) {
      pointsMap[key.toString()] = value.toMap();
    });

    return {
      'name': name,
      'address': address,
      'created_at': Timestamp.fromDate(createdAt),
      'deviceId': deviceId,
      'ownerId': ownerId,
      'points': pointsMap,
      'status': status,
    };
  }

  // Create from Firestore document
  factory Geofence.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Geofence.fromMap(data, doc.id);
  }

  // Create from Map with optional ID
  factory Geofence.fromMap(Map<String, dynamic> map, [String? id]) {
    Map<int, GeofencePoint> pointsMap = {};
    
    if (map['points'] != null && map['points'] is Map) {
      Map<String, dynamic> points = map['points'] as Map<String, dynamic>;
      points.forEach((key, value) {
        int index = int.tryParse(key) ?? 0;
        if (value is Map<String, dynamic>) {
          pointsMap[index] = GeofencePoint.fromMap(value);
        }
      });
    }

    DateTime createdAt = DateTime.now();
    if (map['created_at'] != null) {
      if (map['created_at'] is Timestamp) {
        createdAt = (map['created_at'] as Timestamp).toDate();
      } else if (map['created_at'] is String) {
        createdAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
      }
    }

    return Geofence(
      geofenceId: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      createdAt: createdAt,
      deviceId: map['deviceId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      points: pointsMap,
      status: map['status'] ?? true,
    );
  }

  // Create a unique identifier combining device and user
  String get uniqueIdentifier => '${deviceId}_${ownerId}_${name.replaceAll(' ', '_')}';

  // Validate if geofence has minimum required points
  bool get isValid => points.isNotEmpty && name.isNotEmpty && deviceId.isNotEmpty && ownerId.isNotEmpty;

  // Get all points as a list
  List<GeofencePoint> get pointsList => points.values.toList();

  // Get points ordered by index
  List<GeofencePoint> get orderedPoints {
    List<int> sortedKeys = points.keys.toList()..sort();
    return sortedKeys.map((key) => points[key]!).toList();
  }

  // Add a point at specific index
  Geofence addPoint(int index, GeofencePoint point) {
    Map<int, GeofencePoint> newPoints = Map.from(points);
    newPoints[index] = point;
    return copyWith(points: newPoints);
  }

  // Remove a point at specific index
  Geofence removePoint(int index) {
    Map<int, GeofencePoint> newPoints = Map.from(points);
    newPoints.remove(index);
    return copyWith(points: newPoints);
  }

  // Update a point at specific index
  Geofence updatePoint(int index, GeofencePoint point) {
    Map<int, GeofencePoint> newPoints = Map.from(points);
    newPoints[index] = point;
    return copyWith(points: newPoints);
  }

  // Toggle status
  Geofence toggleStatus() => copyWith(status: !status);

  @override
  String toString() {
    return 'Geofence(geofenceId: $geofenceId, name: $name, address: $address, '
           'deviceId: $deviceId, ownerId: $ownerId, points: ${points.length}, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Geofence &&
        other.geofenceId == geofenceId &&
        other.name == name &&
        other.address == address &&
        other.deviceId == deviceId &&
        other.ownerId == ownerId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return geofenceId.hashCode ^
        name.hashCode ^
        address.hashCode ^
        deviceId.hashCode ^
        ownerId.hashCode ^
        status.hashCode;
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceEditScreen extends StatefulWidget {
  final String geofenceId;
  final Map<String, dynamic> geofenceData;

  const GeofenceEditScreen({
    super.key,
    required this.geofenceId,
    required this.geofenceData,
  });

  @override
  State<GeofenceEditScreen> createState() => _GeofenceEditScreenState();
}

class _GeofenceEditScreenState extends State<GeofenceEditScreen> {
  late List<LatLng> polygonPoints;
  late TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    polygonPoints =
        List<Map<String, dynamic>>.from(
          widget.geofenceData['points'],
        ).map((p) => LatLng(p['lat'], p['lng'])).toList();
    nameController = TextEditingController(text: widget.geofenceData['name']);
  }

  void onSavePressed() async {
    await FirebaseFirestore.instance
        .collection('geofences')
        .doc(widget.geofenceId)
        .update({
          'name': nameController.text.trim(),
          'points':
              polygonPoints
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
        });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geofence updated')));
    }
  }

  void resetPoints() {
    setState(() {
      polygonPoints.clear();
    });
  }

  void undoLastPoint() {
    if (polygonPoints.isNotEmpty) {
      setState(() {
        polygonPoints.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Geofence')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  polygonPoints.isNotEmpty ? polygonPoints.first : LatLng(0, 0),
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  polygonPoints.add(point);
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              if (polygonPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polygonPoints,
                      color: Colors.blueAccent,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
              if (polygonPoints.length >= 3)
                PolygonLayer(
                  polygonCulling: false,
                  polygons: [
                    Polygon(
                      points: [...polygonPoints, polygonPoints.first],
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers:
                    polygonPoints.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final point = entry.value;
                      return Marker(
                        point: point,
                        width: 35,
                        height: 35,
                        child: CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Text(
                            '$index',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
          Positioned(
            bottom: 180,
            left: 16,
            right: 16,
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Geofence Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: undoLastPoint,
              icon: const Icon(Icons.undo),
              label: const Text('Undo Last Point'),
            ),
          ),
          Positioned(
            bottom: 70,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: resetPoints,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Points'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: onSavePressed,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

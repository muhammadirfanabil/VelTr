import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../screens/GeoFence/index.dart';

class GeofenceMapScreen extends StatefulWidget {
  const GeofenceMapScreen({super.key});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen> {
  List<LatLng> polygonPoints = [];
  bool showPolygon = false;

  void onContinuePressed() {
    if (polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal 3 titik diperlukan untuk area geofence'),
        ),
      );
      return;
    }

    setState(() {
      showPolygon = true;
    });
  }

  void onSavePressed() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();

        return AlertDialog(
          title: const Text('Simpan Geofence'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Geofence',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                // TODO: Simpan ke Firestore atau database
                print('Nama Geofence: $name');
                for (var point in polygonPoints) {
                  print('Point: ${point.latitude}, ${point.longitude}');
                }

                Navigator.pop(context);

                // Navigasi ke halaman GeofenceListScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => GeofenceListScreen()),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentukan Area Geofence')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(-3.316378, 114.597325),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                if (showPolygon) return;
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
              if (showPolygon && polygonPoints.length >= 3)
                PolygonLayer(
                  polygonCulling: false,
                  polygons: [
                    Polygon(
                      points: [...polygonPoints, polygonPoints.first],
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blueAccent,
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),

          // Undo tombol
          if (!showPolygon && polygonPoints.isNotEmpty)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    polygonPoints.removeLast();
                  });
                },
                icon: const Icon(Icons.undo),
                label: const Text('Undo Titik Terakhir'),
              ),
            ),

          // Reset tombol
          if (!showPolygon && polygonPoints.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    polygonPoints.clear();
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Reset Titik'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),

          // Tombol Lanjutkan
          if (!showPolygon)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: onContinuePressed,
                child: const Text('Lanjutkan'),
              ),
            ),

          // Tombol Simpan (setelah lanjutkan)
          if (showPolygon)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: onSavePressed,
                icon: const Icon(Icons.save),
                label: const Text('Simpan Geofence'),
              ),
            ),
        ],
      ),
    );
  }
}

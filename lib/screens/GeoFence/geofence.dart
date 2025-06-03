import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../screens/GeoFence/index.dart';
import '../../widgets/mapWidget.dart';

class GeofenceMapScreen extends StatefulWidget {
  const GeofenceMapScreen({super.key});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen> {
  final List<LatLng> _polygonPoints = [];
  bool _isPolygonVisible = false;

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_isPolygonVisible) return;
    setState(() {
      _polygonPoints.add(point);
    });
  }

  void _handleContinue() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal 3 titik diperlukan untuk area geofence'),
        ),
      );
      return;
    }
    setState(() => _isPolygonVisible = true);
  }

  void _handleUndo() {
    if (_polygonPoints.isNotEmpty) {
      setState(() => _polygonPoints.removeLast());
    }
  }

  void _handleReset() {
    setState(() {
      _polygonPoints.clear();
      _isPolygonVisible = false; // Reset polygon visibility too
    });
  }

  void _handleSave() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nama geofence harus diisi'),
                      ),
                    );
                    return;
                  }

                  // TODO: Simpan ke Firestore atau database
                  debugPrint('Nama Geofence: $name');
                  for (final point in _polygonPoints) {
                    debugPrint('Point: ${point.latitude}, ${point.longitude}');
                  }

                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => GeofenceListScreen()),
                  );
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
  }

  List<Marker> _buildMarkers() {
    return _polygonPoints.asMap().entries.map((entry) {
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
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildMapLayers() {
    final layers = <Widget>[
      TileLayer(
        urlTemplate: 'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.gps_app',
      ),
    ];

    // Add polygon layer if visible
    if (_isPolygonVisible && _polygonPoints.length >= 3) {
      layers.add(
        PolygonLayer(
          polygonCulling: false,
          polygons: [
            Polygon(
              points: [..._polygonPoints, _polygonPoints.first],
              color: Colors.blue.withOpacity(0.3),
              borderColor: Colors.blueAccent,
              borderStrokeWidth: 3,
            ),
          ],
        ),
      );
    }

    // Add markers layer
    if (_polygonPoints.isNotEmpty) {
      layers.add(MarkerLayer(markers: _buildMarkers()));
    }

    return layers;
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style:
          color != null
              ? ElevatedButton.styleFrom(backgroundColor: color)
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentukan Area Geofence'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // MapWidget - clean and reusable
          MapWidget(
            options: MapOptions(
              initialCenter: const LatLng(-6.2088, 106.8456), // Default center
              initialZoom: 15.0,
              onTap: _handleMapTap,
            ),
            children: _buildMapLayers(),
          ),

          // Action buttons overlay
          if (!_isPolygonVisible && _polygonPoints.isNotEmpty) ...[
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: _buildActionButton(
                label: 'Undo Titik Terakhir',
                icon: Icons.undo,
                onPressed: _handleUndo,
              ),
            ),
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildActionButton(
                label: 'Reset Titik',
                icon: Icons.delete,
                onPressed: _handleReset,
                color: Colors.red,
              ),
            ),
          ],

          // Main action button
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child:
                !_isPolygonVisible
                    ? ElevatedButton(
                      onPressed:
                          _polygonPoints.length >= 3 ? _handleContinue : null,
                      child: Text(
                        _polygonPoints.isEmpty
                            ? 'Tap pada peta untuk menambah titik'
                            : 'Lanjutkan (${_polygonPoints.length} titik)',
                      ),
                    )
                    : _buildActionButton(
                      label: 'Simpan Geofence',
                      icon: Icons.save,
                      onPressed: _handleSave,
                    ),
          ),

          // Info panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _isPolygonVisible
                    ? 'Area geofence telah dibuat. Tap "Simpan" untuk menyimpan.'
                    : 'Tap pada peta untuk menandai titik-titik area geofence. Minimal 3 titik diperlukan.',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

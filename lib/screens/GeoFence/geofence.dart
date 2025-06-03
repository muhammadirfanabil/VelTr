import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'geofence_list_screen.dart';

class GeofenceMapScreen extends StatefulWidget {
  final String deviceId;
  const GeofenceMapScreen({super.key, required this.deviceId});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen> {
  List<LatLng> polygonPoints = [];
  bool showPolygon = false;
  String? address;
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void onContinuePressed() {
    if (polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least 3 points are required to create a geofence area.',
          ),
        ),
      );
      return;
    }

    setState(() {
      showPolygon = true;
    });
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      }
      return "Address not found";
    } catch (e) {
      return "Error: $e";
    }
  }

  void onSavePressed() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();

        return AlertDialog(
          title: const Text('Save Geofence'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Geofence Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final centerPoint = polygonPoints.reduce(
                  (value, element) => LatLng(
                    (value.latitude + element.latitude) / 2,
                    (value.longitude + element.longitude) / 2,
                  ),
                );

                final fetchedAddress = await getAddressFromLatLng(
                  centerPoint.latitude,
                  centerPoint.longitude,
                );

                setState(() {
                  address = fetchedAddress;
                });

                await FirebaseFirestore.instance.collection('geofences').add({
                  'deviceId': widget.deviceId,
                  'name': name,
                  'address': address,
                  'points':
                      polygonPoints
                          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                          .toList(),
                  'status': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => GeofenceListScreen(deviceId: widget.deviceId),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Define Geofence Area')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: currentLocation!,
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
              if (showPolygon && polygonPoints.length >= 3)
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

          if (!showPolygon && polygonPoints.isNotEmpty)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    polygonPoints.removeLast();
                    if (polygonPoints.length < 3) {
                      showPolygon = false;
                    }
                  });
                },
                icon: const Icon(Icons.undo),
                label: const Text('Undo Last Point'),
              ),
            ),

          if (polygonPoints.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    polygonPoints.clear();
                    showPolygon = false;
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Reset Points'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),

          // Continue button (hanya muncul saat belum selesai)
          if (!showPolygon)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: onContinuePressed,
                child: const Text('Continue'),
              ),
            ),

          // Save button (hanya muncul jika showPolygon dan titik cukup)
          if (showPolygon && polygonPoints.length >= 3)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: onSavePressed,
                icon: const Icon(Icons.save),
                label: const Text('Save Geofence'),
              ),
            ),
        ],
      ),
    );
  }
}

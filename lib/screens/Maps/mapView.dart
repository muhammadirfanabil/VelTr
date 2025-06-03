import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/MapWidget.dart';
import '../../widgets/stickyFooter.dart';
import '../../widgets/motoricon.dart';
import '../../widgets/tracker.dart';

class GPSMapScreen extends StatefulWidget {
  final String deviceId;

  const GPSMapScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  bool isVehicleOn = false;
  final MapController _mapController = MapController();

  LatLng get vehicleLocation =>
      (latitude != null && longitude != null)
          ? LatLng(latitude!, longitude!)
          : LatLng(-6.200000, 106.816666);

  @override
  void initState() {
    super.initState();
    fetchLastLocation();
    fetchVehicleStatus();
  }

  Future<bool> pingESP32(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/ping'))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('Timeout', 408),
          );

      if (response.statusCode == 200) {
        debugPrint("ESP32 responded: ${response.body}");
        return true;
      } else {
        debugPrint(
          "ESP32 not responding properly. Status: ${response.statusCode}",
        );
        return false;
      }
    } catch (e) {
      debugPrint("Error pinging ESP32: $e");
      return false;
    }
  }

  Future<void> fetchLocationName(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterApp'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          locationName = data['display_name'] ?? 'Location Not Found';
        });
      } else {
        setState(() {
          locationName = 'Failed to Load Location';
        });
      }
    } catch (e) {
      setState(() {
        locationName = 'Error: ${e.toString()}';
      });
    }
  }

  void fetchLastLocation() {
    debugPrint('DEBUG: Fetching location for deviceId: ${widget.deviceId}');
    final ref = FirebaseDatabase.instance.ref('devices/${widget.deviceId}/gps');

    ref
        .once()
        .then((DatabaseEvent event) {
          debugPrint(
            'DEBUG: Firebase snapshot exists: ${event.snapshot.exists}',
          );

          if (event.snapshot.exists) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            debugPrint('DEBUG: Firebase data: $data');

            final lat = double.tryParse(data['latitude'].toString());
            final lon = double.tryParse(data['longitude'].toString());
            final timestamp = data['tanggal'];

            debugPrint('DEBUG: Parsed coordinates - lat: $lat, lon: $lon');

            setState(() {
              latitude = lat;
              longitude = lon;

              if (lat != null && lon != null) {
                fetchLocationName(lat, lon);
                _mapController.move(LatLng(lat, lon), 15.0);
                debugPrint('DEBUG: Map moved to: $lat, $lon');
              } else {
                debugPrint('DEBUG: Coordinates are null, marker will not show');
              }

              if (timestamp != null) {
                final dt = DateTime.parse(timestamp);
                lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
              } else {
                lastUpdated = 'Unavailable';
              }
            });
          } else {
            debugPrint(
              'DEBUG: No data found at path: devices/${widget.deviceId}/gps',
            );
          }
        })
        .catchError((error) {
          debugPrint('DEBUG: Firebase error: $error');
        });

    // Fixed: Add null check for real-time updates
    ref.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        final lat = double.tryParse(data['latitude'].toString());
        final lon = double.tryParse(data['longitude'].toString());
        final timestamp = data['tanggal'];

        setState(() {
          latitude = lat;
          longitude = lon;

          if (lat != null && lon != null) {
            fetchLocationName(lat, lon);
            _mapController.move(LatLng(lat, lon), 15.0);
          }

          if (timestamp != null) {
            final dt = DateTime.parse(timestamp);
            lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
          } else {
            lastUpdated = 'Unavailable';
          }
        });
      }
    });
  }

  void fetchVehicleStatus() {
    // Fixed: Use correct Firebase path for isActive
    final ref = FirebaseDatabase.instance.ref(
      'devices/${widget.deviceId}/gps/isActive',
    );
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      setState(() {
        isVehicleOn = data == true;
      });
    });
  }

  bool get isRecentlyActive {
    if (lastUpdated == '-' || lastUpdated == 'Unavailable') return false;

    try {
      final lastUpdate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(lastUpdated);
      final now = DateTime.now();
      final difference = now.difference(lastUpdate);

      // Consider active if updated within last 5 minutes
      return difference.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }

  void toggleVehicleStatus() {
    // Fixed: Use correct Firebase path - only need to update isActive
    final statusRef = FirebaseDatabase.instance.ref(
      'devices/${widget.deviceId}/gps/isActive',
    );

    final newStatus = !isVehicleOn;

    statusRef.set(newStatus);

    setState(() {
      isVehicleOn = newStatus;
    });
  }

  void showVehiclePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleStatusPanel(
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: lastUpdated,
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(
                -2.2180,
                113.9220,
              ), // Default center, will be updated by GPS
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            deviceId: widget.deviceId, // Pass deviceId to MapWidget
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gps_app',
              ),
              MarkerLayer(
                markers: [
                  // Vehicle marker - show based on recent activity
                  if (latitude != null && longitude != null && isRecentlyActive)
                    Marker(
                      point: LatLng(latitude!, longitude!),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: showVehiclePanel,
                        child: VehicleMarkerIcon(isOn: isRecentlyActive),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

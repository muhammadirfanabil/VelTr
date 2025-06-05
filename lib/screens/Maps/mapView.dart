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
  int? satellites;
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  String? waktuWita;
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
    final ref = FirebaseDatabase.instance.ref('devices/${widget.deviceId}/gps');

    ref
        .once()
        .then((DatabaseEvent event) {
          if (event.snapshot.exists) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);

            final lat = double.tryParse(data['latitude'].toString());
            final lon = double.tryParse(data['longitude'].toString());
            final tanggal = data['tanggal'];
            final waktu = data['waktu_wita'];
            final sat =
                data['satellites'] != null
                    ? int.tryParse(data['satellites'].toString())
                    : null;

            String? timestamp;
            if (tanggal != null && waktu != null) {
              timestamp = '$tanggal $waktu';
            }

            debugPrint('DEBUG: Parsed coordinates - lat: $lat, lon: $lon');

            setState(() {
              latitude = lat;
              longitude = lon;
              waktuWita = waktu;
              satellites = sat;

              if (lat != null && lon != null) {
                fetchLocationName(lat, lon);
                _mapController.move(LatLng(lat, lon), 15.0);
                debugPrint('DEBUG: Map moved to: $lat, $lon');
              } else {
                debugPrint('DEBUG: Coordinates are null, marker will not show');
              }

              if (timestamp != null) {
                final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
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
        final tanggal = data['tanggal'];
        final waktu = data['waktu_wita'];
        final sat =
            data['satellites'] != null
                ? int.tryParse(data['satellites'].toString())
                : null;

        setState(() {
          latitude = lat;
          longitude = lon;
          waktuWita = waktu;
          satellites = sat;

          if (lat != null && lon != null) {
            fetchLocationName(lat, lon);
            _mapController.move(LatLng(lat, lon), 15.0);
          }

          if (tanggal != null && waktu != null) {
            final timestamp = '$tanggal $waktu';
            try {
              final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
              lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
            } catch (_) {
              lastUpdated = 'Unavailable';
            }
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
      'devices/${widget.deviceId}/relay',
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
    final relayRef = FirebaseDatabase.instance.ref(
      'devices/${widget.deviceId}/relay',
    );

    final newStatus = !isVehicleOn;

    relayRef.set(newStatus);

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
            waktuWita: waktuWita,
            lastUpdated: lastUpdated,
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
            satellites: satellites,
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
                  if (latitude != null && longitude != null)
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// import '../../services/Auth/AuthService.dart';
import '../../widgets/MapWidget.dart';
import '../../widgets/stickyFooter.dart';
import '../../widgets/motoricon.dart'; // Import your VehicleMarkerIcon
import '../../widgets/tracker.dart'; // Import VehicleStatusPanel

class GPSMapScreen extends StatefulWidget {
  final String deviceId; // Add this line to define the deviceId

  const GPSMapScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String? locationName = 'Loading Location...';
  bool isVehicleOn = false; // Menyimpan status kendaraan

  @override
  void initState() {
    super.initState();
    fetchLastLocation();
    fetchVehicleStatus(); // Memanggil fungsi untuk memantau status kendaraan
    fetchRelayStatus();
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
    // Ensure deviceId is passed properly to avoid null issues
    final ref = FirebaseDatabase.instance.ref('devices/${widget.deviceId}/gps');

    ref.once().then((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Accessing the nested keys directly
        final lat = double.tryParse(data['latitude'].toString());
        final lon = double.tryParse(data['longitude'].toString());
        final timestamp = data['tanggal']; // Retrieve the correct field

        setState(() {
          latitude = lat;
          longitude = lon;

          if (lat != null && lon != null) {
            fetchLocationName(lat, lon);
            _mapController.move(LatLng(lat, lon), 15.0);
          }

          if (timestamp != null) {
            final dt = DateTime.parse(
              timestamp,
            ); // Updated to use DateTime.parse for the string date
            lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
          } else {
            lastUpdated = 'Unavailable';
          }
        });
      }
    });

    ref.onValue.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // Repeating the same structure for real-time updates
      final lat = double.tryParse(data['latitude'].toString());
      final lon = double.tryParse(data['longitude'].toString());
      final timestamp = data['tanggal'];

      setState(() {
        latitude = double.tryParse(data['latitude'].toString());
        longitude = double.tryParse(data['longitude'].toString());

        if (lat != null && lon != null) {
          fetchLocationName(lat, lon);
          _mapController.move(LatLng(lat, lon), 15.0);
        }

        final timestamp = data['timestamp'];
        if (timestamp != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            int.parse(timestamp.toString()),
          );
          lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
        } else {
          lastUpdated = 'Unavailable';
        }
      });
    });
  }

  void fetchVehicleStatus() {
    final ref = FirebaseDatabase.instance.ref('GPS/status_kendaraan');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      setState(() {
        isVehicleOn = data == true;
      });
    });
  }

  void toggleVehicleStatus() {
    final ref = FirebaseDatabase.instance.ref('GPS/status_kendaraan');
    final relayRef = FirebaseDatabase.instance.ref(
      'GPS/relay',
    ); // Menambahkan referensi untuk relay

    // Toggle status kendaraan dan relay
    ref.set(!isVehicleOn); // Toggle status kendaraan
    relayRef.set(isVehicleOn ? true : false); // Kirimkan status relay

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
            options: MapOptions(
              initialCenter: const LatLng(
                -2.2180,
                113.9220,
              ), // Default to Central Kalimantan
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile-{s}.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gps_app',
              ),
              // Add VehicleMarkerIcon here - only on home page
              if (latitude != null && longitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude!, longitude!),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: showVehiclePanel,
                        child: VehicleMarkerIcon(isOn: isVehicleOn),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyFooter(), // ini bakal nempel di bawah layar!
          ),
        ],
      ),
    );
  }
}

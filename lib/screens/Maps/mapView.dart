import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/Auth/AuthService.dart';
import '../../widgets/MapWidget.dart';

class GPSMapScreen extends StatefulWidget {
  const GPSMapScreen({super.key});

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String? locationName = 'Loading Location...';
  bool isVehicleOn = false; // Menyimpan status kendaraan
  int? satellites; // Menyimpan jumlah satellites

  @override
  void initState() {
    super.initState();
    fetchLastLocation();
    fetchVehicleStatus();
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
        headers: {
          'User-Agent': 'FlutterApp', // User-Agent wajib diisi
        },
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
    final ref = FirebaseDatabase.instance.ref('GPS');
    ref.onValue.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      setState(() {
        latitude = double.tryParse(data['latitude'].toString());
        longitude = double.tryParse(data['longitude'].toString());

        // Ambil data satellites jika ada
        if (data.containsKey('satellites')) {
          satellites = int.tryParse(data['satellites'].toString());
        } else {
          satellites = null;
        }

        if (latitude != null && longitude != null) {
          fetchLocationName(
            latitude!,
            longitude!,
          ); // Pemanggilan API untuk mendapatkan nama lokasi
        }

        final waktuWita = data['waktu_wita'];
        if (waktuWita != null) {
          try {
            final dt = DateFormat(
              'yyyy-MM-dd HH:mm:ss',
            ).parse(waktuWita.toString());
            lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
          } catch (e) {
            lastUpdated = 'Invalid WITA format';
          }
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
        isVehicleOn = data == true; // Asumsikan status kendaraan adalah boolean
      });
    });
  }

  void toggleVehicleStatus() {
    final ref = FirebaseDatabase.instance.ref('GPS/status_kendaraan');
    final relayRef = FirebaseDatabase.instance.ref('GPS/relay');

    // Toggle status kendaraan dan relay
    ref.set(!isVehicleOn); // Toggle status kendaraan
    relayRef.set(isVehicleOn ? true : false); // Kirimkan status relay

    setState(() {
      isVehicleOn = !isVehicleOn; // Update status lokal
    });
  }

  void fetchRelayStatus() {
    final ref = FirebaseDatabase.instance.ref('GPS/relay');
    ref.onValue.listen((event) {
      final data = event.snapshot.value;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const MapWidget(), // Menampilkan Peta
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/appicon1.svg',
                          height: 25,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            fetchLastLocation();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loading Location...'),
                              ),
                            );
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.person, color: Colors.black),
                          offset: const Offset(0, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          color: Colors.white,
                          shadowColor: Colors.black.withOpacity(0.2),
                          onSelected: (value) async {
                            if (value == 'profile') {
                              Navigator.pushNamed(context, '/profile');
                            } else if (value == 'settings') {
                              Navigator.pushNamed(context, '/settings');
                            } else if (value == 'logout') {
                              await AuthService.signOut();
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'profile',
                                  child: Row(
                                    children: const [
                                      SizedBox(width: 8),
                                      Text('Profile'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: const [
                                      SizedBox(width: 8),
                                      Text('Settings'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: const [
                                      SizedBox(width: 8),
                                      Text('Logout'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locationName ?? 'Loading...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      (latitude != null && longitude != null)
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Lat: ${latitude!.toStringAsFixed(5)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Lng: ${longitude!.toStringAsFixed(5)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Tampilkan satellites jika ada
                              satellites != null
                                  ? Text(
                                    'Satellites: $satellites',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.black87,
                                    ),
                                  )
                                  : const SizedBox.shrink(),
                            ],
                          )
                          : Text(
                            'Unavailable',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lastUpdated != true
                        ? 'Last Active: $lastUpdated'
                        : 'Waiting...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green[300],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Wrap(
                        spacing: 50,
                        runSpacing: 10,
                        alignment: WrapAlignment.start,
                        children: [
                          ElevatedButton(
                            onPressed:
                                (latitude != null && longitude != null)
                                    ? () {}
                                    : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(5, 45),
                              backgroundColor: const Color(
                                0xFF7DAEFF,
                              ).withOpacity(0.25),
                              foregroundColor: const Color(0xFF11468F),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Transform.rotate(
                                  angle: 0.45,
                                  child: const Icon(Icons.navigation, size: 25),
                                ),
                                const Text('Navigate the Distance From You'),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: toggleVehicleStatus,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(5, 45),
                              backgroundColor:
                                  isVehicleOn
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  isVehicleOn
                                      ? Icons.power_settings_new
                                      : Icons.power_settings_new_outlined,
                                  size: 25,
                                ),
                                Text(
                                  isVehicleOn
                                      ? 'Turn Off Vehicle'
                                      : 'Turn On Vehicle',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

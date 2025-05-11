import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../widgets/MapWidget.dart';
import 'package:intl/intl.dart';

class GPSMapScreen extends StatefulWidget {
  const GPSMapScreen({super.key});

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  String lastUpdated = '-';
  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    fetchLastLocation();
  }

  void fetchLastLocation() {
    final ref = FirebaseDatabase.instance.ref('GPS');
    ref.onValue.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      setState(() {
        latitude = double.tryParse(data['latitude'].toString());
        longitude = double.tryParse(data['longitude'].toString());
        final timestamp = data['timestamp'];
        if (timestamp != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(
            int.parse(timestamp.toString()),
          );
          lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
        } else {
          lastUpdated = 'Waktu tidak tersedia';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const MapWidget(), // Menampilkan Peta
          // Top Bar: Logo & Profil
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
                  borderRadius: BorderRadius.circular(32),
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
                        Image.asset('assets/images/appicon.png', height: 30),
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
                                content: Text('Memuat ulang lokasi...'),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.person),
                          onPressed: () {
                            // Tampilkan profil user
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lokasi Terakhir:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (latitude != null && longitude != null)
                        ? 'Lat: $latitude\nLng: $longitude'
                        : 'Belum tersedia',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update: $lastUpdated',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Tambahkan fungsi hitung jarak
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate the distance from you'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 50),
                          primary: Colors.blue.shade700,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kendaraan dimatikan!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Turn off your vehicle'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 50),
                          primary: Colors.red.shade600,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/');
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 50),
                          primary: Colors.grey.shade600,
                        ),
                      ),
                    ],
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

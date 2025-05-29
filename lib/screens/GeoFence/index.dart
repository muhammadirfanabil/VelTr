import 'package:flutter/material.dart';
import '../GeoFence/geofence.dart';

class GeofenceListScreen extends StatefulWidget {
  const GeofenceListScreen({super.key});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  final List<Map<String, String>> geofences = [
    {
      'name': 'Poliban',
      'address':
          'Jl. Brig Jend. Hasan Basri, Pangeran, Kec. Banjarmasin Utara, Kota Banjarmasin, Kalimantan Selatan 70124',
    },
    {
      'name': 'Unlam',
      'address':
          'Jl. Brig Jend. Hasan Basri, Pangeran, Kec. Banjarmasin Utara, Kota Banjarmasin, Kalimantan Selatan 70124',
    },
    {
      'name': 'Banjarbaru',
      'address':
          'Jl. Husni Thamrin, Loktabat Utara, Kec. Banjarbaru Utara, Kota Banjar Baru, Kalimantan Selatan 70714',
    },
  ];

  late List<bool> geofenceActive;

  @override
  void initState() {
    super.initState();
    geofenceActive = List<bool>.filled(
      geofences.length,
      true,
    ); // semua aktif di awal
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GeofenceMapScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: geofences.length,
        itemBuilder: (context, index) {
          final item = geofences[index];
          return ListTile(
            leading: const Icon(Icons.location_on, color: Colors.black),
            title: Text(
              item['name']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item['address']!,
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Switch(
              value: geofenceActive[index],
              onChanged: (value) {
                setState(() {
                  geofenceActive[index] = value;
                });
              },
              activeColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

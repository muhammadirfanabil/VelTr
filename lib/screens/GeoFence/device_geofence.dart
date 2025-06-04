import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../GeoFence/index.dart'; // Pastikan GeofenceListScreen ada di sini

class DeviceListScreen extends StatefulWidget {
  final String deviceId;

  const DeviceListScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final DatabaseReference devicesRef = FirebaseDatabase.instance.ref(
    'devices/',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: StreamBuilder<DatabaseEvent>(
        stream: devicesRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading devices'));
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('No devices found'));
          }

          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final deviceEntries = data.entries.toList();

          return ListView.builder(
            itemCount: deviceEntries.length,
            itemBuilder: (context, index) {
              final deviceKey = deviceEntries[index].key;
              final deviceData =
                  deviceEntries[index].value as Map<dynamic, dynamic>;

              // Ambil nama device, kalau kosong pakai deviceKey
              final deviceName = (deviceData['name'] ?? '').toString().trim();
              final displayName =
                  deviceName.isEmpty ? deviceKey.toString() : deviceName;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.blue),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('ID: $deviceKey'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GeofenceListScreen(
                              deviceId: deviceKey.toString(),
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

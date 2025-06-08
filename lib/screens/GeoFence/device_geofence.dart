import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'index.dart';

class DeviceListScreen extends StatefulWidget {
  final String deviceId;

  const DeviceListScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  String? ownerId;

  @override
  void initState() {
    super.initState();
    // Ambil UID user yang sedang login
    ownerId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (ownerId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('devices')
                .where('ownerId', isEqualTo: ownerId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading devices'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No devices found'));
          }

          final devices = snapshot.data!.docs;

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final doc = devices[index];
              final deviceId = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().trim();
              final displayName = name.isEmpty ? deviceId : name;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Colors.blue),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('ID: $deviceId'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GeofenceListScreen(deviceId: deviceId),
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

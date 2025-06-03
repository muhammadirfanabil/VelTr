import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../GeoFence/geofence.dart';
import 'geofence_edit_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  final String deviceId;
  const GeofenceListScreen({super.key, required this.deviceId});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  @override
  Widget build(BuildContext context) {
    final geofencesQuery = FirebaseFirestore.instance
        .collection('geofences')
        .where('deviceId', isEqualTo: widget.deviceId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Geofences for ${widget.deviceId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GeofenceMapScreen(deviceId: widget.deviceId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: geofencesQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading geofences'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No geofences found'));
          }

          final geofences = snapshot.data!.docs;

          return ListView.builder(
            itemCount: geofences.length,
            itemBuilder: (context, index) {
              final doc = geofences[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;

              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Confirm Delete'),
                          content: Text(
                            'Are you sure you want to delete "${data['name'] ?? 'this geofence'}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                },
                onDismissed: (direction) async {
                  await doc.reference.delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geofence deleted')),
                  );
                },
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.black),
                  title: Text(
                    data['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    data['address'] ?? 'No Address',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Switch(
                    value: data['status'] ?? false,
                    onChanged: (value) {
                      doc.reference.update({'status': value});
                    },
                    activeColor: Colors.green,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GeofenceEditScreen(
                              geofenceId: docId,
                              geofenceData: data,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Geofence')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('waktu', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada notifikasi'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final status = data['status'] ?? '';
              final geofenceName = data['geofenceName'] ?? '';
              final waktu = (data['waktu'] as Timestamp?)?.toDate();
              final location = data['location'];

              return ListTile(
                leading: Icon(
                  status == 'Masuk area' ? Icons.login : Icons.logout,
                  color: status == 'Masuk area' ? Colors.green : Colors.red,
                ),
                title: Text(status),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Area: $geofenceName'),
                    if (location != null)
                      Text('Lokasi: (${location['lat']}, ${location['lng']})'),
                    if (waktu != null) Text('Waktu: ${waktu.toLocal()}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

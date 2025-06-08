import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .orderBy('waktu', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Geofence notifications will appear here',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              final geofenceName = data['geofenceName'] ?? '';
              final waktu = (data['waktu'] as Timestamp?)?.toDate();
              final location = data['location'];

              final isEntering =
                  status == 'Masuk area' ||
                  status.toLowerCase().contains('enter');

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await _showDeleteConfirmation(context);
                },
                onDismissed: (direction) async {
                  await _deleteNotification(doc.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Notification deleted'),
                        backgroundColor: Colors.grey[800],
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              isEntering
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEntering ? Icons.login : Icons.logout,
                          color: isEntering ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main notification text
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  height: 1.3,
                                ),
                                children: [
                                  TextSpan(
                                    text: isEntering ? 'Entered ' : 'Exited ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: geofenceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (location != null) ...[
                                    const TextSpan(text: ' at '),
                                    TextSpan(
                                      text:
                                          '${location['lat']?.toStringAsFixed(4)}, ${location['lng']?.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Time
                            Text(
                              waktu != null
                                  ? _getTimeAgo(waktu)
                                  : 'Unknown time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Optional: Three dots menu
                      Icon(Icons.more_horiz, color: Colors.grey[400], size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Notification'),
          content: const Text(
            'Are you sure you want to delete this notification?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}

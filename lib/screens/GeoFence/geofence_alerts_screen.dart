import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/geofence/geofence_alert_service.dart';
import '../../services/notifications/enhanced_notification_service.dart';

class GeofenceAlertsScreen extends StatefulWidget {
  const GeofenceAlertsScreen({Key? key}) : super(key: key);

  @override
  State<GeofenceAlertsScreen> createState() => _GeofenceAlertsScreenState();
}

class _GeofenceAlertsScreenState extends State<GeofenceAlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GeofenceAlertService _alertService = GeofenceAlertService();
  final EnhancedNotificationService _notificationService =
      EnhancedNotificationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Geofence Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.notifications_active), text: 'Recent'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'clear_all':
                  await _clearAllAlerts();
                  break;
                case 'test_notification':
                  await _notificationService.sendTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification sent!')),
                  );
                  break;
                case 'settings':
                  _showNotificationSettings();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all),
                        SizedBox(width: 8),
                        Text('Clear All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'test_notification',
                    child: Row(
                      children: [
                        Icon(Icons.notification_add),
                        SizedBox(width: 8),
                        Text('Test Notification'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRecentAlertsTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildRecentAlertsTab() {
    return StreamBuilder<int>(
      stream: _notificationService.getUnreadNotificationCount(),
      builder: (context, countSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _notificationService.getNotificationsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(
                'Error loading alerts: ${snapshot.error}',
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                'No Recent Alerts',
                'Geofence alerts will appear here when your vehicles enter or exit geofences.',
                Icons.notifications_none,
              );
            }

            // Get recent notifications (last 24 hours)
            final recentDocs =
                snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  if (timestamp == null) return false;
                  return DateTime.now().difference(timestamp).inHours <= 24;
                }).toList();

            if (recentDocs.isEmpty) {
              return _buildEmptyState(
                'No Recent Alerts',
                'No geofence alerts in the last 24 hours.',
                Icons.notifications_none,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recentDocs.length,
                itemBuilder: (context, index) {
                  final doc = recentDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final alert = GeofenceAlert(
                    id: doc.id,
                    deviceId: data['deviceId'] ?? '',
                    deviceName: data['deviceName'] ?? 'Unknown Device',
                    geofenceName: data['geofenceName'] ?? 'Unknown Geofence',
                    action: data['action'] ?? 'unknown',
                    timestamp:
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    latitude: data['latitude']?.toDouble() ?? 0.0,
                    longitude: data['longitude']?.toDouble() ?? 0.0,
                    isRead: data['read'] ?? false,
                  );

                  return _buildAlertCard(alert, true);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildEmptyState(
        'Not Logged In',
        'Please log in to view your alert history.',
        Icons.account_circle,
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading history: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            'No History',
            'Your geofence alert history will appear here.',
            Icons.history,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final alert = GeofenceAlert(
              id: doc.id,
              deviceId: data['deviceId'] ?? '',
              deviceName: data['deviceName'] ?? 'Unknown Device',
              geofenceName: data['geofenceName'] ?? 'Unknown Geofence',
              action: data['action'] ?? 'unknown',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              latitude: data['latitude']?.toDouble() ?? 0.0,
              longitude: data['longitude']?.toDouble() ?? 0.0,
              isRead: data['read'] ?? false,
            );

            return _buildAlertCard(alert, false);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(GeofenceAlert alert, bool isRecent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isRecent && !alert.isRead ? 4 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isRecent && !alert.isRead) {
            _alertService.markAlertAsRead(alert.id);
            setState(() {});
          }
          _showAlertDetails(alert);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                isRecent && !alert.isRead
                    ? LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAlertIcon(alert),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.deviceName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isRecent && !alert.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '${alert.actionText} ',
                              style: TextStyle(
                                color: alert.actionColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: alert.geofenceName),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(alert.timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertIcon(GeofenceAlert alert) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: alert.actionColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: alert.actionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(alert.actionIcon, color: alert.actionColor, size: 24),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 24),
            const Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDetails(GeofenceAlert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAlertIcon(alert),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.deviceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '${alert.actionText} ${alert.geofenceName}',
                            style: TextStyle(
                              color: alert.actionColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Time', _formatDateTime(alert.timestamp)),
                _buildDetailRow('Action', alert.actionText.toUpperCase()),
                _buildDetailRow('Geofence', alert.geofenceName),
                _buildDetailRow('Device', alert.deviceName),
                if (alert.latitude != 0 && alert.longitude != 0)
                  _buildDetailRow(
                    'Location',
                    '${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}',
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to map view with this location
                          _navigateToMapLocation(alert);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View on Map'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _clearAllAlerts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Alerts'),
            content: const Text(
              'Are you sure you want to clear all recent alerts? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _notificationService.clearAllNotifications();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All alerts cleared successfully!')),
        );
      }
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notification Settings'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Push Notifications'),
                  subtitle: Text(
                    'Receive alerts when vehicles enter/exit geofences',
                  ),
                  trailing: Switch(value: true, onChanged: null),
                ),
                ListTile(
                  leading: Icon(Icons.vibration),
                  title: Text('Vibration'),
                  subtitle: Text('Vibrate when receiving alerts'),
                  trailing: Switch(value: true, onChanged: null),
                ),
                ListTile(
                  leading: Icon(Icons.volume_up),
                  title: Text('Sound'),
                  subtitle: Text('Play sound for notifications'),
                  trailing: Switch(value: true, onChanged: null),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _navigateToMapLocation(GeofenceAlert alert) {
    // Navigate to map view with alert location
    // This would integrate with your existing map navigation
    debugPrint('Navigate to map: ${alert.latitude}, ${alert.longitude}');
  }
}

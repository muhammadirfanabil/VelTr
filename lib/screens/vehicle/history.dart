import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DrivingHistory extends StatefulWidget {
  const DrivingHistory({super.key});

  @override
  State<DrivingHistory> createState() => _DrivingHistoryState();
}

class _DrivingHistoryState extends State<DrivingHistory> {
  // Dummy data for now - will be replaced with Firebase data later
  final List<DrivingActivity> _activities = [
    // Yesterday
    DrivingActivity(
      id: '1',
      type: ActivityType.started,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      location: 'Jl. Tjilik Riwut, Palangkaraya',
      duration: const Duration(hours: 2, minutes: 30),
      distance: 45.2,
    ),
    DrivingActivity(
      id: '2',
      type: ActivityType.stopped,
      timestamp: DateTime.now().subtract(
        const Duration(days: 1, hours: 5, minutes: 30),
      ),
      location: 'Mall Palangkaraya',
      duration: const Duration(hours: 2, minutes: 30),
      distance: 45.2,
    ),
    DrivingActivity(
      id: '3',
      type: ActivityType.alert,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 10)),
      location: 'Jl. Ahmad Yani, Palangkaraya',
      message: 'Speeding detected: 85 km/h in 60 km/h zone',
    ),

    // Last Week
    DrivingActivity(
      id: '4',
      type: ActivityType.started,
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 14)),
      location: 'Universitas Palangkaraya',
      duration: const Duration(hours: 1, minutes: 45),
      distance: 23.8,
    ),
    DrivingActivity(
      id: '5',
      type: ActivityType.maintenance,
      timestamp: DateTime.now().subtract(const Duration(days: 5, hours: 9)),
      location: 'Bengkel Jaya Motor',
      message: 'Oil change completed',
    ),
    DrivingActivity(
      id: '6',
      type: ActivityType.stopped,
      timestamp: DateTime.now().subtract(const Duration(days: 6, hours: 16)),
      location: 'Pasar Kahayan, Palangkaraya',
      duration: const Duration(hours: 3, minutes: 15),
      distance: 12.5,
    ),

    // Last 30 Days
    DrivingActivity(
      id: '7',
      type: ActivityType.longTrip,
      timestamp: DateTime.now().subtract(const Duration(days: 15, hours: 7)),
      location: 'Banjarmasin - Palangkaraya',
      duration: const Duration(hours: 6, minutes: 45),
      distance: 387.5,
    ),
    DrivingActivity(
      id: '8',
      type: ActivityType.alert,
      timestamp: DateTime.now().subtract(const Duration(days: 18, hours: 20)),
      location: 'Jl. Cilik Riwut KM 5',
      message: 'Hard braking detected',
    ),
    DrivingActivity(
      id: '9',
      type: ActivityType.started,
      timestamp: DateTime.now().subtract(const Duration(days: 22, hours: 11)),
      location: 'Rumah Sakit Doris Sylvanus',
      duration: const Duration(minutes: 45),
      distance: 8.3,
    ),
    DrivingActivity(
      id: '10',
      type: ActivityType.maintenance,
      timestamp: DateTime.now().subtract(const Duration(days: 28, hours: 13)),
      location: 'AHASS Honda Palangkaraya',
      message: 'Routine service completed',
    ),
  ];

  List<DrivingActivity> get yesterdayActivities {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _activities.where((activity) {
      return activity.timestamp.day == yesterday.day &&
          activity.timestamp.month == yesterday.month &&
          activity.timestamp.year == yesterday.year;
    }).toList();
  }

  List<DrivingActivity> get lastWeekActivities {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities.where((activity) {
      return activity.timestamp.isAfter(weekAgo) &&
          !_isToday(activity.timestamp) &&
          !_isYesterday(activity.timestamp);
    }).toList();
  }

  List<DrivingActivity> get last30DaysActivities {
    final monthAgo = DateTime.now().subtract(const Duration(days: 30));
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities.where((activity) {
      return activity.timestamp.isAfter(monthAgo) &&
          activity.timestamp.isBefore(weekAgo);
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Driving History',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (yesterdayActivities.isNotEmpty) ...[
            _buildSectionHeader('Yesterday'),
            const SizedBox(height: 12),
            ...yesterdayActivities.map(
              (activity) => _buildActivityItem(activity),
            ),
            const SizedBox(height: 24),
          ],

          if (lastWeekActivities.isNotEmpty) ...[
            _buildSectionHeader('This Week'),
            const SizedBox(height: 12),
            ...lastWeekActivities.map(
              (activity) => _buildActivityItem(activity),
            ),
            const SizedBox(height: 24),
          ],

          if (last30DaysActivities.isNotEmpty) ...[
            _buildSectionHeader('This Month'),
            const SizedBox(height: 12),
            ...last30DaysActivities.map(
              (activity) => _buildActivityItem(activity),
            ),
          ],

          if (_activities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No driving history available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildActivityItem(DrivingActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getActivityColor(activity.type).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getActivityIcon(activity.type),
              color: _getActivityColor(activity.type),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Activity Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: _getActivityTitle(activity),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (activity.location != null) ...[
                              const TextSpan(text: ' at '),
                              TextSpan(
                                text: activity.location!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Text(
                      _formatTimeAgo(activity.timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),

                if (activity.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.message!,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],

                if (activity.duration != null || activity.distance != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (activity.duration != null) ...[
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(activity.duration!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (activity.duration != null &&
                          activity.distance != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (activity.distance != null) ...[
                        Icon(
                          Icons.straighten,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.distance!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.started:
        return Icons.play_circle_filled;
      case ActivityType.stopped:
        return Icons.stop_circle;
      case ActivityType.alert:
        return Icons.warning;
      case ActivityType.maintenance:
        return Icons.build_circle;
      case ActivityType.longTrip:
        return Icons.route;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.started:
        return Colors.green;
      case ActivityType.stopped:
        return Colors.blue;
      case ActivityType.alert:
        return Colors.orange;
      case ActivityType.maintenance:
        return Colors.purple;
      case ActivityType.longTrip:
        return Colors.indigo;
    }
  }

  String _getActivityTitle(DrivingActivity activity) {
    switch (activity.type) {
      case ActivityType.started:
        return 'Started driving';
      case ActivityType.stopped:
        return 'Stopped driving';
      case ActivityType.alert:
        return 'Safety alert';
      case ActivityType.maintenance:
        return 'Maintenance';
      case ActivityType.longTrip:
        return 'Long trip completed';
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

// Data Models
enum ActivityType { started, stopped, alert, maintenance, longTrip }

class DrivingActivity {
  final String id;
  final ActivityType type;
  final DateTime timestamp;
  final String? location;
  final Duration? duration;
  final double? distance;
  final String? message;

  DrivingActivity({
    required this.id,
    required this.type,
    required this.timestamp,
    this.location,
    this.duration,
    this.distance,
    this.message,
  });

  // Future method to convert from Firebase data
  factory DrivingActivity.fromFirebase(Map<String, dynamic> data) {
    return DrivingActivity(
      id: data['id'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => ActivityType.started,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0),
      location: data['location'],
      duration:
          data['duration'] != null
              ? Duration(milliseconds: data['duration'])
              : null,
      distance: data['distance']?.toDouble(),
      message: data['message'],
    );
  }

  // Method to convert to Firebase data
  Map<String, dynamic> toFirebase() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'location': location,
      'duration': duration?.inMilliseconds,
      'distance': distance,
      'message': message,
    };
  }
}

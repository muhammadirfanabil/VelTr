import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../services/history/history_service.dart';

class DrivingHistory extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;

  const DrivingHistory({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
  });

  @override
  State<DrivingHistory> createState() => _DrivingHistoryState();
}

class _DrivingHistoryState extends State<DrivingHistory> {
  bool _isLoading = true;
  String? _error;
  List<HistoryEntry> _historyEntries = [];
  List<LatLng> _polylinePoints = [];
  int _selectedDays = 7;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchDrivingHistory();
  }
  Future<void> _fetchDrivingHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await HistoryService.fetchDrivingHistory(
        vehicleId: widget.vehicleId,
        days: _selectedDays,
      );

      setState(() {
        _historyEntries = entries;
        _polylinePoints = entries.map((e) => LatLng(e.latitude, e.longitude)).toList();
        _isLoading = false;      });

      // Center map on first point if available
      if (_polylinePoints.isNotEmpty) {
        _mapController.move(_polylinePoints.first, 13.0);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _changeDateRange(int days) {
    if (_selectedDays != days) {
      setState(() {
        _selectedDays = days;
      });
      _fetchDrivingHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vehicleName} - Driving History'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Show last: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1, 3, 7, 14, 30].map((days) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(days == 1 ? '24 hours' : '$days days'),
                            selected: _selectedDays == days,
                            onSelected: (_) => _changeDateRange(days),
                            selectedColor: Colors.blue.shade100,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats Summary
          if (!_isLoading && _historyEntries.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Points', '${_historyEntries.length}', Icons.place),
                  _buildStatItem('Distance', '${_calculateTotalDistance().toStringAsFixed(1)} km', Icons.route),
                  _buildStatItem('Duration', _calculateTotalDuration(), Icons.timer),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Map or Loading/Error State
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge,
              child: _buildMapContent(),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading driving history...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDrivingHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No driving history found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The vehicle hasn\'t been active in the selected time period.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _polylinePoints.isNotEmpty ? _polylinePoints.first : const LatLng(-2.2088, 113.9213),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.gps_app',
        ),
        
        // Polyline showing the driving path
        if (_polylinePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _polylinePoints,
                strokeWidth: 4.0,
                color: Colors.blue.shade600,
                pattern: const StrokePattern.solid(),
              ),
            ],
          ),

        // Markers for start and end points
        MarkerLayer(
          markers: [
            // Start marker (green)
            if (_polylinePoints.isNotEmpty)
              Marker(
                point: _polylinePoints.first,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            
            // End marker (red)
            if (_polylinePoints.length > 1)
              Marker(
                point: _polylinePoints.last,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.stop,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            
            // Intermediate points (blue dots)
            ..._polylinePoints.skip(1).take(_polylinePoints.length - 2).map((point) =>
              Marker(
                point: point,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateTotalDistance() {
    if (_polylinePoints.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    final Distance distance = const Distance();
    
    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      final d = distance.as(
        LengthUnit.Kilometer,
        _polylinePoints[i],
        _polylinePoints[i + 1],
      );
      totalDistance += d;
    }
    
    return totalDistance;
  }

  String _calculateTotalDuration() {
    if (_historyEntries.length < 2) return '0h 0m';
    
    final startTime = _historyEntries.first.createdAt;
    final endTime = _historyEntries.last.createdAt;
    final duration = endTime.difference(startTime);
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    return '${hours}h ${minutes}m';
  }
}

class HistoryEntry {
  final String id;
  final DateTime createdAt;
  final LatLng location;

  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.location,
  });
}
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

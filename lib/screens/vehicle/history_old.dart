import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/history/history_service.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';
import '../../widgets/history/vehicle_selector_widget.dart';
import '../../widgets/history/vehicle_selection_modal.dart';
import '../../widgets/history/date_range_selector_widget.dart';
import '../../widgets/history/history_statistics_widget.dart';
import '../../widgets/history/history_map_widget.dart';

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
  final List<int> _dayOptions = [1, 3, 7];
  final MapController _mapController = MapController();

  // Vehicle selector state
  vehicle? _selectedVehicle;
  List<vehicle> _availableVehicles = [];
  bool _isLoadingVehicles = false;
  final VehicleService _vehicleService = VehicleService();
  @override
  void initState() {
    super.initState();
    _initializeVehicleAndHistory();
  }

  Future<void> _initializeVehicleAndHistory() async {
    await _loadVehicles();

    // Set initial selected vehicle based on the passed vehicleId
    if (_availableVehicles.isNotEmpty) {
      _selectedVehicle = _availableVehicles.firstWhere(
        (v) => v.id == widget.vehicleId,
        orElse: () => _availableVehicles.first,
      );
    }

    await _fetchDrivingHistory();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final vehicles = await _vehicleService.getVehiclesStream().first;
      setState(() {
        _availableVehicles = vehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      setState(() {
        _availableVehicles = [];
        _isLoadingVehicles = false;
      });
    }
  }

  Future<void> _fetchDrivingHistory() async {
    if (_selectedVehicle == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await HistoryService.fetchDrivingHistory(
        vehicleId: _selectedVehicle!.id,
        days: _selectedDays,
      );

      setState(() {
        _historyEntries = entries;
        _polylinePoints =
            entries.map((e) => LatLng(e.latitude, e.longitude)).toList();
        _isLoading = false;
        _error = null; // Clear any previous errors
      });

      // Center map on first point if available
      if (_polylinePoints.isNotEmpty) {
        _mapController.move(_polylinePoints.first, 13.0);
      }
    } catch (e) {
      print('Error in history screen: $e');
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
        title: const Text('Driving History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(        children: [
          // Vehicle Selector Header
          VehicleSelectorWidget(
            selectedVehicle: _selectedVehicle,
            availableVehicles: _availableVehicles,
            isLoadingVehicles: _isLoadingVehicles,
            onTap: _showVehicleSelector,
          ),
          // Date Range Selector
          DateRangeSelectorWidget(
            selectedDays: _selectedDays,
            dayOptions: _dayOptions,
            onDaysChanged: _changeDateRange,
          ),          // Statistics Card
          if (!_isLoading && _historyEntries.isNotEmpty)
            HistoryStatisticsWidget(historyEntries: _historyEntries),

          // Map
          Expanded(
            child: HistoryMapWidget(
              historyEntries: _historyEntries,
              polylinePoints: _polylinePoints,
              mapController: _mapController,
              isLoading: _isLoading,
              error: _error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: Colors.blue[600],
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingVehicles
                      ? 'Loading vehicles...'
                      : _selectedVehicle?.name ?? 'No vehicle selected',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (_selectedVehicle?.plateNumber?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _selectedVehicle!.plateNumber!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_availableVehicles.length > 1)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showVehicleSelector,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_availableVehicles.length == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                'Only Vehicle',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return ToggleButtons(
      isSelected: _dayOptions.map((days) => _selectedDays == days).toList(),
      onPressed: (index) {
        final selectedDays = _dayOptions[index];
        _changeDateRange(selectedDays);
      },
      borderRadius: BorderRadius.circular(8),
      selectedBorderColor: Colors.blue[600],
      selectedColor: Colors.white,
      fillColor: Colors.blue[600],
      color: Colors.grey[700],
      borderColor: Colors.grey[300],
      borderWidth: 1.5,
      constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('1 Day', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('3 Days', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('7 Days', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final stats = HistoryService.getDrivingStatistics(_historyEntries);
    final totalDistance = stats['totalDistance'] as double;
    final totalPoints = stats['totalPoints'] as int;
    final timeSpan = stats['timeSpan'] as Duration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driving Statistics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Distance',
                _formatDistance(totalDistance),
                Icons.timeline,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                'Data Points',
                totalPoints.toString(),
                Icons.location_on,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                'Time Span',
                _formatDuration(timeSpan),
                Icons.access_time,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
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
            Icon(Icons.route_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No driving history found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This vehicle has no recorded trips in the selected time period.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            _polylinePoints.isNotEmpty
                ? _polylinePoints.first
                : const LatLng(-2.2180, 113.9217),
        initialZoom: 13.0,
        maxZoom: 18.0,
        minZoom: 5.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.gps_app',
        ),
        if (_polylinePoints.isNotEmpty) ...[
          // Driving path polyline
          PolylineLayer(
            polylines: [
              Polyline(
                points: _polylinePoints,
                strokeWidth: 4.0,
                color: Colors.blue[600]!,
              ),
            ],
          ),
          // Start and end markers
          MarkerLayer(
            markers: [
              // Start marker
              Marker(
                width: 40.0,
                height: 40.0,
                point: _polylinePoints.first,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ), // End marker
              if (_polylinePoints.length > 1)
                Marker(
                  width: 40.0,
                  height: 40.0,
                  point: _polylinePoints.last,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Select Vehicle',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Vehicle list
                Expanded(
                  child:
                      _isLoadingVehicles
                          ? const Center(child: CircularProgressIndicator())
                          : _availableVehicles.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_car_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No vehicles found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _availableVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = _availableVehicles[index];
                              final isSelected =
                                  _selectedVehicle?.id == vehicle.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Colors.blue
                                            : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  color:
                                      isSelected
                                          ? Colors.blue[50]
                                          : Colors.white,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Colors.blue
                                              : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.directions_car,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.grey[600],
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    vehicle.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isSelected
                                              ? Colors.blue[700]
                                              : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (vehicle.plateNumber?.isNotEmpty ==
                                          true)
                                        Text(
                                          'Plate: ${vehicle.plateNumber}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (vehicle.vehicleTypes?.isNotEmpty ==
                                          true)
                                        Text(
                                          'Type: ${vehicle.vehicleTypes}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing:
                                      isSelected
                                          ? Icon(
                                            Icons.check_circle,
                                            color: Colors.blue[600],
                                          )
                                          : null,
                                  onTap: () {
                                    _selectVehicle(vehicle);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  void _selectVehicle(vehicle newVehicle) {
    if (_selectedVehicle?.id != newVehicle.id) {
      setState(() {
        _selectedVehicle = newVehicle;
      });
      _fetchDrivingHistory();
    }
  }
}

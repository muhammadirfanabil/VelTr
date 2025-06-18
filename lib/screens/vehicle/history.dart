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
import '../../widgets/history/empty_state_widgets.dart';

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
      if (widget.vehicleId.isNotEmpty) {
        _selectedVehicle = _availableVehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => _availableVehicles.first,
        );
      } else {
        _selectedVehicle = _availableVehicles.first;
      }
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

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VehicleSelectionModal(
        availableVehicles: _availableVehicles,
        selectedVehicle: _selectedVehicle,
        isLoadingVehicles: _isLoadingVehicles,
        onVehicleSelected: _selectVehicle,
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

  @override
  Widget build(BuildContext context) {
    // Handle empty states
    if (_isLoadingVehicles) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driving History'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text('Loading vehicles...'),
            ],
          ),
        ),
      );
    }

    if (_availableVehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driving History'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: VehicleEmptyStateWidget(
          onAddVehicle: () {
            Navigator.pushNamed(context, '/manage-vehicle');
          },
        ),
      );
    }

    if (_selectedVehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driving History'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const VehicleSelectionPromptWidget(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving History'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
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
          ),
          // Statistics Card
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
}

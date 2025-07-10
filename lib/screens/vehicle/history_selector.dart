import 'package:flutter/material.dart';
import 'package:gps_app/services/history/history_service.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../models/vehicle/vehicle.dart';
import 'history.dart';
import 'dart:async';

class DrivingHistorySelector extends StatefulWidget {
  const DrivingHistorySelector({super.key});

  @override
  State<DrivingHistorySelector> createState() => _DrivingHistorySelectorState();
}

class _DrivingHistorySelectorState extends State<DrivingHistorySelector> {
  final VehicleService _vehicleService = VehicleService();
  vehicle? _selectedVehicle;
  DateTime? _selectedDate; // Fixed: Use DateTime instead of HistoryEntry
  bool _isLoading = true;
  List<vehicle> _vehicles = [];
  StreamSubscription<List<vehicle>>? _vehiclesSubscription;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _vehiclesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);

    try {
      // Listen to vehicles stream and properly manage subscription
      _vehiclesSubscription = _vehicleService.getVehiclesStream().listen(
        (vehicles) {
          if (mounted) {
            setState(() {
              _vehicles = vehicles;
              _isLoading = false;
              // Auto-select first vehicle if available and none selected
              if (_selectedVehicle == null && vehicles.isNotEmpty) {
                _selectedVehicle = vehicles.first;
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading vehicles: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue[600]!),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Driving History'),
            if (!_isLoading && _vehicles.isNotEmpty) ...[
              const SizedBox(width: 16),
              const Text('•'),
              const SizedBox(width: 16),
              Expanded(child: _buildVehicleDropdown()),
            ],
          ],
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedVehicle != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                switch (value) {
                  case 'select_date':
                    _selectDate();
                    break;
                  case 'clear_filter':
                    _clearDateFilter();
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'select_date',
                      child: Row(
                        children: [
                          Icon(Icons.date_range, size: 20),
                          SizedBox(width: 8),
                          Text('Filter by Date'),
                        ],
                      ),
                    ),
                    if (_selectedDate != null)
                      const PopupMenuItem(
                        value: 'clear_filter',
                        child: Row(
                          children: [
                            Icon(Icons.clear, size: 20),
                            SizedBox(width: 8),
                            Text('Clear Filter'),
                          ],
                        ),
                      ),
                  ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Date filter indicator
          if (_selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered by: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _clearDateFilter,
                    icon: Icon(Icons.close, color: Colors.blue[600], size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<vehicle>(
          value: _selectedVehicle,
          hint: const Text(
            'Select Vehicle',
            style: TextStyle(color: Colors.white70),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: Colors.blue[700],
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (vehicle? newVehicle) {
            setState(() {
              _selectedVehicle = newVehicle;
              // Clear date filter when switching vehicles
              _selectedDate = null;
            });
          },
          items:
              _vehicles.map<DropdownMenuItem<vehicle>>((vehicle vehicleItem) {
                return DropdownMenuItem<vehicle>(
                  value: vehicleItem,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vehicleItem.name,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Loading vehicles...'),
          ],
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Vehicles Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please add a vehicle first to view driving history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/manage-vehicle');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Add Vehicle'),
            ),
          ],
        ),
      );
    }

    if (_selectedVehicle == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Select a Vehicle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a vehicle from the dropdown above to view its driving history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Show the actual driving history for the selected vehicle
    return DrivingHistory(
      vehicleId: _selectedVehicle!.id,
      vehicleName: _selectedVehicle!.name,
      createdAt: _selectedDate, // Pass the selected date filter
    );
  }
}

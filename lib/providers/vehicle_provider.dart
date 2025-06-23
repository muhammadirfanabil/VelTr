import 'package:flutter/foundation.dart';
import '../models/vehicle/vehicle.dart';
import '../services/vehicle/vehicleService.dart';

/// Provider for managing the currently selected vehicle across the app
class VehicleProvider extends ChangeNotifier {
  vehicle? _selectedVehicle;
  List<vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  final VehicleService _vehicleService;

  VehicleProvider({VehicleService? vehicleService})
    : _vehicleService = vehicleService ?? VehicleService();

  // Getters
  vehicle? get selectedVehicle => _selectedVehicle;
  List<vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasSelectedVehicle => _selectedVehicle != null;

  /// Initialize the provider by loading vehicles
  Future<void> initialize() async {
    await loadVehicles();
  }

  /// Load all vehicles for the current user
  Future<void> loadVehicles() async {
    _setLoading(true);
    _error = null;

    try {
      // Listen to vehicle changes
      _vehicleService.getVehiclesStream().listen(
        (vehicles) {
          _vehicles = vehicles;

          // If no vehicle is selected and we have vehicles, select the first one
          if (_selectedVehicle == null && vehicles.isNotEmpty) {
            _selectedVehicle = vehicles.first;
          }

          // If the selected vehicle is no longer in the list, clear selection
          if (_selectedVehicle != null &&
              !vehicles.any((v) => v.id == _selectedVehicle!.id)) {
            _selectedVehicle = null;
          }

          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          _setLoading(false);
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Select a specific vehicle
  void selectVehicle(vehicle selectedVehicle) {
    if (_selectedVehicle?.id != selectedVehicle.id) {
      _selectedVehicle = selectedVehicle;
      notifyListeners();

      // Optional: Save selection to local storage for persistence
      _saveSelectedVehicle(selectedVehicle.id);
    }
  }

  /// Clear vehicle selection
  void clearSelection() {
    _selectedVehicle = null;
    notifyListeners();
    _saveSelectedVehicle(null);
  }

  /// Get vehicle by ID
  vehicle? getVehicleById(String vehicleId) {
    try {
      return _vehicles.firstWhere((v) => v.id == vehicleId);
    } catch (e) {
      return null;
    }
  }

  /// Private method to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Save selected vehicle ID to shared preferences (optional)
  Future<void> _saveSelectedVehicle(String? vehicleId) async {
    // TODO: Implement with SharedPreferences if you want persistence
    // final prefs = await SharedPreferences.getInstance();
    // if (vehicleId != null) {
    //   await prefs.setString('selected_vehicle_id', vehicleId);
    // } else {
    //   await prefs.remove('selected_vehicle_id');
    // }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../services/Auth/AuthService.dart';
import '../../services/maps/mapsService.dart';
import '../../services/device/deviceService.dart';
import '../../widgets/mapWidget.dart';
import '../../widgets/stickyFooter.dart';
import '../../widgets/motoricon.dart';
import '../../widgets/tracker.dart';

class GPSMapScreen extends StatefulWidget {
  final String deviceId;

  const GPSMapScreen({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<GPSMapScreen> createState() => _GPSMapScreenState();
}

class _GPSMapScreenState extends State<GPSMapScreen> {
  late final DeviceService _deviceService;
  mapServices? _mapService;
  String? currentDeviceId;
  String? deviceName;

  String lastUpdated = '-';
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  bool isVehicleOn = false;
  bool isLoading = true;
  final MapController _mapController = MapController();

  LatLng get vehicleLocation =>
      (latitude != null && longitude != null)
          ? LatLng(latitude!, longitude!)
          : const LatLng(-6.200000, 106.816666);

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();
    _initializeWithUserDevice();
  }

  Future<void> _initializeWithUserDevice() async {
    try {
      setState(() => isLoading = true);

      final macId = await _deviceService.getValidatedDeviceMacIdForMap();
      if (macId == null) {
        throw Exception(
          'No valid devices found or device not connected to GPS system',
        );
      }

      final name = await _deviceService.getDeviceNameById(macId);
      final mapService = mapServices(deviceId: macId);

      setState(() {
        currentDeviceId = macId;
        deviceName = name ?? macId;
        _mapService = mapService;
      });

      _setupRealtimeListeners();
      await _loadInitialData();
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  void _handleInitializationError(dynamic e) {
    debugPrint('Error initializing with user device: $e');
    if (mounted) {
      setState(() => isLoading = false);

      String errorMessage = _getErrorMessage(e);
      _showErrorSnackBar(errorMessage);
    }
  }

  String _getErrorMessage(dynamic e) {
    final errorString = e.toString();
    if (errorString.contains('No valid devices found')) {
      return 'No GPS devices found or device not connected to GPS system. Please check your device setup.';
    } else if (errorString.contains('not connected to GPS system')) {
      return 'Device found but not sending GPS data. Please check your physical GPS device connection.';
    }
    return 'Failed to initialize device: $e';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _setupRealtimeListeners() {
    if (_mapService == null) return;

    _mapService!.getGPSDataStream().listen((gpsData) {
      if (mounted && gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        _updateGPSData(gpsData);
      }
    });

    _mapService!.getRelayStatusStream().listen((relayStatus) {
      if (mounted) setState(() => isVehicleOn = relayStatus);
    });
  }

  Future<void> _updateGPSData(Map<String, dynamic> gpsData) async {
    try {
      final lat = gpsData['latitude'] as double;
      final lon = gpsData['longitude'] as double;

      // Fetch location name asynchronously
      _mapService?.fetchLocationName(lat, lon).then((locationName) {
        if (mounted) setState(() => this.locationName = locationName);
      });

      setState(() {
        latitude = lat;
        longitude = lon;
        lastUpdated =
            gpsData['waktu_wita']?.toString() ??
            gpsData['time']?.toString() ??
            DateTime.now().toString();
        isLoading = false;
      });

      _mapController.move(LatLng(lat, lon), 15.0);
    } catch (e) {
      debugPrint('Error updating GPS data: $e');
    }
  }

  Future<void> _loadInitialData() async {
    if (_mapService == null) return;

    try {
      final gpsData = await _mapService!.getLastGPSLocation();
      if (gpsData != null && _mapService!.isGPSDataValid(gpsData)) {
        await _updateGPSData(gpsData);
      }

      final relayStatus = await _mapService!.getCurrentRelayStatus();
      if (mounted) {
        setState(() {
          isVehicleOn = relayStatus;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool get isRecentlyActive {
    if (lastUpdated == '-' || lastUpdated == 'Unavailable') return false;

    try {
      final lastUpdate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(lastUpdated);
      final difference = DateTime.now().difference(lastUpdate);
      return difference.inMinutes <= 5;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleVehicleStatus() async {
    if (_mapService == null) return;

    try {
      await _mapService!.toggleRelayStatus();
    } catch (e) {
      debugPrint('Error toggling vehicle status: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to toggle vehicle: $e');
      }
    }
  }

  void showVehiclePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleStatusPanel(
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: lastUpdated,
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
          ),
    );
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await _loadInitialData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildDeviceInfoChip() {
    if (deviceName == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        deviceName!,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildFloatingButton(
          child:
              isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          onPressed: isLoading ? null : _refreshData,
        ),
        const SizedBox(width: 8),
        _buildUserMenu(),
      ],
    );
  }

  Widget _buildFloatingButton({
    required Widget child,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(icon: child, onPressed: onPressed),
    );
  }

  Widget _buildUserMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.person, color: Colors.black),
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        color: Colors.white,
        onSelected: _handleMenuSelection,
        itemBuilder:
            (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_outlined),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'logout':
        await AuthService.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: vehicleLocation,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            deviceId: currentDeviceId,
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.gps_app',
                maxZoom: 18,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: vehicleLocation,
                    width: 80,
                    height: 80,
                    child: GestureDetector(
                      onTap: showVehiclePanel,
                      child: VehicleMarkerIcon(isOn: isVehicleOn),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildDeviceInfoChip(), _buildActionButtons()],
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

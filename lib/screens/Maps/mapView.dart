import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

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
  int? satellites;
  double? latitude;
  double? longitude;
  String locationName = 'Loading Location...';
  String? waktuWita;
  bool isVehicleOn = false;
  bool isLoading = true;
  bool hasGPSData = false; // Add this flag
  final MapController _mapController = MapController();

  // Remove the default LatLng getter and make it nullable
  LatLng? get vehicleLocation =>
      (latitude != null && longitude != null)
          ? LatLng(latitude!, longitude!)
          : null;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();
    currentDeviceId = widget.deviceId;
    _initializeWithDevice();
  }

  Future<void> _initializeWithDevice() async {
    try {
      setState(() => isLoading = true);

      final name = await _deviceService.getDeviceNameById(widget.deviceId);
      final mapService = mapServices(deviceId: widget.deviceId);

      setState(() {
        deviceName = name ?? widget.deviceId;
        _mapService = mapService;
      });

      _setupRealtimeListeners();
      await _loadInitialData();
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  void _handleInitializationError(dynamic e) {
    debugPrint('Error initializing device: $e');
    if (mounted) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to initialize device: $e');
    }
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
    _listenToGPSData();
    _listenToRelayStatus();
  }

  void _listenToGPSData() {
    final ref = FirebaseDatabase.instance.ref('devices/${widget.deviceId}/gps');

    ref.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          debugPrint('GPS Data received: $data');

          final lat = _parseDouble(data['latitude']);
          final lon = _parseDouble(data['longitude']);
          final tanggal = data['tanggal']?.toString();
          final waktu = data['waktu_wita']?.toString();
          final sat = _parseInt(data['satellites']);

          if (lat != null && lon != null) {
            setState(() {
              latitude = lat;
              longitude = lon;
              waktuWita = waktu;
              satellites = sat;
              isLoading = false;
              hasGPSData = true; // Set GPS data available
            });

            _fetchLocationName(lat, lon);
            _mapController.move(LatLng(lat, lon), 15.0);

            if (tanggal != null && waktu != null) {
              _updateTimestamp('$tanggal $waktu');
            }
          } else {
            setState(() {
              isLoading = false;
              hasGPSData = false;
            });
            _showNoGPSDataDialog();
          }
        } else {
          debugPrint(
            'No GPS data found at path: devices/${widget.deviceId}/gps',
          );
          setState(() {
            isLoading = false;
            hasGPSData = false;
          });
          _showNoGPSDataDialog();
        }
      },
      onError: (error) {
        debugPrint('Firebase GPS listener error: $error');
        setState(() {
          isLoading = false;
          hasGPSData = false;
        });
        _showNoGPSDataDialog();
      },
    );
  }

  void _showNoGPSDataDialog() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.gps_off, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('No GPS Data'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS data not found for this device.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  'Device ID: ${widget.deviceId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please check:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• Device is powered on'),
                const Text('• GPS module is functioning'),
                const Text('• Device has network connection'),
                const Text('• Device is sending data to Firebase'),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _refreshData();
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: const Text('Go Back'),
              ),
            ],
          );
        },
      );
    }
  }

  void _listenToRelayStatus() {
    final relayRef = FirebaseDatabase.instance.ref(
      'devices/${widget.deviceId}/relay',
    );

    relayRef.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final status = event.snapshot.value as bool? ?? false;
          if (mounted) {
            setState(() => isVehicleOn = status);
          }
        }
      },
      onError: (error) {
        debugPrint('Firebase relay listener error: $error');
      },
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _updateTimestamp(String timestamp) {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timestamp);
      setState(() {
        lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      });
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      setState(() {
        lastUpdated = 'Invalid timestamp';
      });
    }
  }

  Future<void> _loadInitialData() async {
    final ref = FirebaseDatabase.instance.ref('devices/${widget.deviceId}/gps');

    try {
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        debugPrint('Initial GPS Data: $data');

        final lat = _parseDouble(data['latitude']);
        final lon = _parseDouble(data['longitude']);

        if (lat != null && lon != null) {
          setState(() {
            latitude = lat;
            longitude = lon;
            waktuWita = data['waktu_wita']?.toString();
            satellites = _parseInt(data['satellites']);
            isLoading = false;
            hasGPSData = true;
          });

          _fetchLocationName(lat, lon);
          _mapController.move(LatLng(lat, lon), 15.0);

          final tanggal = data['tanggal']?.toString();
          final waktu = data['waktu_wita']?.toString();
          if (tanggal != null && waktu != null) {
            _updateTimestamp('$tanggal $waktu');
          }
        } else {
          setState(() {
            isLoading = false;
            hasGPSData = false;
          });
          _showNoGPSDataDialog();
        }
      } else {
        setState(() {
          isLoading = false;
          hasGPSData = false;
        });
        _showNoGPSDataDialog();
      }

      // Get initial relay status
      final relaySnapshot =
          await FirebaseDatabase.instance
              .ref('devices/${widget.deviceId}/relay')
              .get();
      if (relaySnapshot.exists) {
        setState(() {
          isVehicleOn = relaySnapshot.value as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() {
        isLoading = false;
        hasGPSData = false;
      });
      _showNoGPSDataDialog();
    }
  }

  Future<void> _fetchLocationName(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterApp'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            locationName = data['display_name'] ?? 'Location Not Found';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching location name: $e");
    }
  }

  void toggleVehicleStatus() {
    final relayRef = FirebaseDatabase.instance.ref(
      'devices/${widget.deviceId}/relay',
    );

    final newStatus = !isVehicleOn;
    relayRef.set(newStatus);

    setState(() {
      isVehicleOn = newStatus;
    });
  }

  void showVehiclePanel() {
    if (!hasGPSData) return; // Don't show panel if no GPS data

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => VehicleStatusPanel(
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            waktuWita: waktuWita,
            lastUpdated: lastUpdated,
            isVehicleOn: isVehicleOn,
            toggleVehicleStatus: toggleVehicleStatus,
            satellites: satellites,
          ),
    );
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await _loadInitialData();

    if (mounted && hasGPSData) {
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

  Widget _buildNoGPSContent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'No GPS Data Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Device: ${deviceName ?? widget.deviceId}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Show loading indicator while loading
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          // Show no GPS content if no GPS data
          else if (!hasGPSData)
            _buildNoGPSContent()
          // Show map only if GPS data is available
          else if (vehicleLocation != null)
            MapWidget(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: vehicleLocation!,
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
                      point: vehicleLocation!,
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

          // Only show top controls if GPS data is available
          if (hasGPSData && !isLoading)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDeviceInfoChip(), _buildActionButtons()],
                ),
              ),
            ),

          // Only show footer if GPS data is available
          if (hasGPSData && !isLoading)
            Align(alignment: Alignment.bottomCenter, child: StickyFooter()),
        ],
      ),
    );
  }
}

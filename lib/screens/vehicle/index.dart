import 'package:flutter/material.dart';
import '../../widgets/stickyFooter.dart';

import '../../models/vehicle/vehicle.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../services/device/deviceService.dart';
import '../../models/Device/device.dart';

class VehicleIndexScreen extends StatefulWidget {
  const VehicleIndexScreen({Key? key}) : super(key: key);

  @override
  _VehicleIndexScreenState createState() => _VehicleIndexScreenState();
}

class _VehicleIndexScreenState extends State<VehicleIndexScreen> {
  final VehicleService _vehicleService = VehicleService();
  final DeviceService _deviceService = DeviceService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Vehicle Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: Colors.black,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: Colors.grey[300]),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildSettingsSection([                    _SettingItem(
                      icon: Icons.directions_car_outlined,
                      title: 'Manage Vehicle',
                      subtitle: 'Add, edit, or remove vehicles',
                      onTap:
                          () => Navigator.pushNamed(context, '/manage-vehicle'),
                    ),
                    _SettingItem(
                      icon: Icons.devices_outlined,
                      title: 'Vehicle-Device Management',
                      subtitle: 'Attach or detach devices to vehicles',
                      onTap: () => _showDeviceManagementModal(context),
                    ),
                    _SettingItem(
                      icon: Icons.location_on_outlined,
                      title: 'Set Geofence',
                      subtitle: 'Create safe zones and boundaries',
                      onTap: () => Navigator.pushNamed(context, '/geofence'),
                    ),
                    _SettingItem(
                      icon: Icons.straighten_outlined,
                      title: 'Set Range',
                      subtitle: 'Configure distance limits',
                      onTap: () => Navigator.pushNamed(context, '/set-range'),
                    ),
                    _SettingItem(
                      icon: Icons.history_outlined,
                      title: 'Driving History',
                      subtitle: 'View past trips and analytics',
                      onTap:
                          () => Navigator.pushNamed(context, '/drive-history'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const StickyFooter(),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(List<_SettingItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 0.5),
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Column(
        children: items.map((item) => _buildSettingTile(item)).toList(),
      ),
    );
  }

  Widget _buildSettingTile(_SettingItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(item.icon, color: Colors.black87, size: 22),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        subtitle:
            item.subtitle != null
                ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.subtitle!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                )
                : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
        onTap: item.onTap,
      ),
    );
  }  void _showDeviceManagementModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vehicle-Device Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: DeviceManagementContent(
                  vehicleService: _vehicleService,
                  deviceService: _deviceService,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceManagementContent extends StatefulWidget {
  final VehicleService vehicleService;
  final DeviceService deviceService;
  final ScrollController scrollController;

  const DeviceManagementContent({
    Key? key,
    required this.vehicleService,
    required this.deviceService,
    required this.scrollController,
  }) : super(key: key);

  @override
  _DeviceManagementContentState createState() => _DeviceManagementContentState();
}

class _DeviceManagementContentState extends State<DeviceManagementContent> {
  List<vehicle> vehicles = [];
  List<Device> devices = [];
  bool isLoading = true;
  String? selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);
      
      // Load vehicles from stream (take first value)
      final vehicleStream = widget.vehicleService.getVehiclesStream();
      final loadedVehicles = await vehicleStream.first;
      
      // Load devices from stream (take first value)
      final deviceStream = widget.deviceService.getDevicesStream();
      final loadedDevices = await deviceStream.first;
      
      setState(() {
        vehicles = loadedVehicles;
        devices = loadedDevices;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Vehicle Selection
        _buildSectionHeader('Select Vehicle'),
        const SizedBox(height: 10),
        _buildVehicleSelection(),
        const SizedBox(height: 20),
        
        // Device Management
        if (selectedVehicleId != null) ...[
          _buildSectionHeader('Attached Devices'),
          const SizedBox(height: 10),
          _buildAttachedDevices(),
          const SizedBox(height: 20),
          _buildSectionHeader('Available Devices'),
          const SizedBox(height: 10),
          _buildAvailableDevices(),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildVehicleSelection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedVehicleId,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          hintText: 'Choose a vehicle',
        ),        items: vehicles.map((vehicle) {
          return DropdownMenuItem<String>(
            value: vehicle.id,
            child: Text(vehicle.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedVehicleId = value;
          });
        },
      ),
    );
  }

  Widget _buildAttachedDevices() {
    if (selectedVehicleId == null) return const SizedBox.shrink();
    
    final attachedDevices = devices.where((device) => 
      device.vehicleId == selectedVehicleId
    ).toList();

    if (attachedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'No devices attached to this vehicle',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: attachedDevices.map((device) => _buildDeviceCard(
        device: device,
        isAttached: true,
        onTap: () => _detachDevice(device),
        actionIcon: Icons.remove_circle_outline,
        actionColor: Colors.red,
      )).toList(),
    );
  }

  Widget _buildAvailableDevices() {
    if (selectedVehicleId == null) return const SizedBox.shrink();
    
    final availableDevices = devices.where((device) => 
      device.vehicleId == null || device.vehicleId!.isEmpty
    ).toList();

    if (availableDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'No available devices to attach',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: availableDevices.map((device) => _buildDeviceCard(
        device: device,
        isAttached: false,
        onTap: () => _attachDevice(device),
        actionIcon: Icons.add_circle_outline,
        actionColor: Colors.green,
      )).toList(),
    );
  }

  Widget _buildDeviceCard({
    required Device device,
    required bool isAttached,
    required VoidCallback onTap,
    required IconData actionIcon,
    required Color actionColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAttached ? Colors.green[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.device_hub,
            color: isAttached ? Colors.green : Colors.blue,
            size: 20,
          ),
        ),        title: Text(
          device.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),subtitle: Text(
          'ID: ${device.id}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: IconButton(
          icon: Icon(actionIcon, color: actionColor),
          onPressed: onTap,
        ),
      ),
    );
  }
  Future<void> _attachDevice(Device device) async {
    if (selectedVehicleId == null) return;

    try {
      await widget.deviceService.updateDevice(
        device.copyWith(vehicleId: selectedVehicleId),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device attached successfully')),
      );
      
      _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error attaching device: $e')),
      );
    }
  }

  Future<void> _detachDevice(Device device) async {
    try {
      await widget.deviceService.updateDevice(
        device.copyWith(vehicleId: null),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device detached successfully')),
      );
      
      _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error detaching device: $e')),
      );
    }
  }
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

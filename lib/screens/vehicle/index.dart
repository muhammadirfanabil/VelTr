import 'package:flutter/material.dart';
import '../../widgets/stickyFooter.dart';

class VehicleIndexScreen extends StatelessWidget {
  const VehicleIndexScreen({super.key});

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
                  _buildSettingsSection([
                    _SettingItem(
                      icon: Icons.directions_car_outlined,
                      title: 'Manage Vehicle',
                      subtitle: 'Add, edit, or remove vehicles',
                      onTap:
                          () => Navigator.pushNamed(context, '/manage-vehicle'),
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
  }

  Widget _buildDivider() {
    return Container(height: 8, color: Colors.grey[50]);
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

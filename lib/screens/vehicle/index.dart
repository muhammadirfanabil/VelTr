import 'package:flutter/material.dart';
import '../../widgets/Common/stickyFooter.dart';

class VehicleIndexScreen extends StatefulWidget {
  const VehicleIndexScreen({Key? key}) : super(key: key);

  @override
  _VehicleIndexScreenState createState() => _VehicleIndexScreenState();
}

class _VehicleIndexScreenState extends State<VehicleIndexScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          Colors.white, // Make scaffold transparent to show gradient
      appBar: AppBar(
        title: const Text(
          'Vehicle Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.2)],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      const SizedBox(height: 8),
                      _buildSettingsSection([
                        _SettingItem(
                          icon: Icons.directions_car_outlined,
                          title: 'Manage Vehicle',
                          subtitle: 'Add, edit, or remove vehicles',
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/manage-vehicle',
                              ),
                        ),
                        _SettingItem(
                          icon: Icons.location_on_outlined,
                          title: 'Manage Device',
                          subtitle: 'Manage your devices',
                          onTap: () => Navigator.pushNamed(context, '/device'),
                        ),
                        _SettingItem(
                          icon: Icons.location_on_outlined,
                          title: 'Set Geofence',
                          subtitle: 'Create safe zones and boundaries',
                          onTap:
                              () => Navigator.pushNamed(context, '/geofence'),
                        ),
                        _SettingItem(
                          icon: Icons.straighten_outlined,
                          title: 'Set Range',
                          subtitle: 'Configure distance limits',
                          onTap:
                              () => Navigator.pushNamed(context, '/set-range'),
                        ),
                        _SettingItem(
                          icon: Icons.history_outlined,
                          title: 'Driving History',
                          subtitle: 'View past trips and analytics',
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/drive-history',
                              ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            const StickyFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(List<_SettingItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: items.map((item) => _buildSettingTile(item)).toList(),
      ),
    );
  }

  Widget _buildSettingTile(_SettingItem item) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(item.icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          item.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle:
            item.subtitle != null
                ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: theme.colorScheme.onSurfaceVariant,
          size: 16,
        ),
        onTap: item.onTap,
      ),
    );
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

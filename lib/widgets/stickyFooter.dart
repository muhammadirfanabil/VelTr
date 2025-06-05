import 'package:flutter/material.dart';

class StickyFooter extends StatelessWidget {
  final String? currentRoute;

  const StickyFooter({super.key, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    // Get current route if not provided
    final String currentRouteName =
        currentRoute ?? ModalRoute.of(context)?.settings.name ?? '';

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.location_on_outlined,
            activeIcon: Icons.location_on,
            label: 'Home',
            route: '/home',
            isActive: _isRouteActive(currentRouteName, '/home'),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.two_wheeler_outlined,
            activeIcon: Icons.two_wheeler,
            label: 'Vehicle',
            route: '/vehicle',
            isActive: _isRouteActive(currentRouteName, '/vehicle'),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'Alerts',
            route: '/notifications',
            isActive: _isRouteActive(currentRouteName, '/notifications'),
          ),
          _buildNavItem(
            context: context,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            route: '/profile',
            isActive: _isRouteActive(currentRouteName, '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            Navigator.pushNamed(context, route);
          }
        },
        splashColor: Colors.grey[100],
        highlightColor: Colors.transparent,
        child: Container(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? const Color(0xFF11468F) : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? const Color(0xFF11468F) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRouteActive(String currentRoute, String targetRoute) {
    // Handle exact matches
    if (currentRoute == targetRoute) return true;

    // Handle sub-routes (e.g., /vehicle/settings should make vehicle tab active)
    if (targetRoute == '/vehicle' &&
        (currentRoute.startsWith('/vehicle') ||
            currentRoute.startsWith('/manage-vehicle') ||
            currentRoute.startsWith('/geofence') ||
            currentRoute.startsWith('/set-range') ||
            currentRoute.startsWith('/drive-history'))) {
      return true;
    }

    // Handle home route variations
    if (targetRoute == '/home' &&
        (currentRoute == '/' || currentRoute.isEmpty)) {
      return true;
    }

    return false;
  }
}

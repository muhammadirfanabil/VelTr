import 'package:flutter/material.dart';

class StickyFooter extends StatefulWidget {
  final String? currentRoute;

  const StickyFooter({super.key, this.currentRoute});

  @override
  State<StickyFooter> createState() => _StickyFooterState();
}

class _StickyFooterState extends State<StickyFooter>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentRouteName =
        widget.currentRoute ?? ModalRoute.of(context)?.settings.name ?? '';

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAnimatedNavItem(
            context: context,
            icon: Icons.location_on_outlined,
            activeIcon: Icons.location_on,
            label: 'Home',
            route: '/home',
            isActive: _isRouteActive(currentRouteName, '/home'),
          ),
          _buildAnimatedNavItem(
            context: context,
            icon: Icons.two_wheeler_outlined,
            activeIcon: Icons.two_wheeler,
            label: 'Vehicle',
            route: '/vehicle',
            isActive: _isRouteActive(currentRouteName, '/vehicle'),
          ),
          _buildAnimatedNavItem(
            context: context,
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'Notifications',
            route: '/notifications',
            isActive: _isRouteActive(currentRouteName, '/notifications'),
          ),
          _buildAnimatedNavItem(
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

  Widget _buildAnimatedNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) {
          _scaleController.forward();
        },
        onTapUp: (_) {
          _scaleController.reverse();
        },
        onTapCancel: () {
          _scaleController.reverse();
        },
        child: InkWell(
          onTap: () {
            if (!isActive) {
              _animationController.forward().then((_) {
                Navigator.pushNamed(context, route);
                _animationController.reset();
              });
            }
          },
          splashColor: Colors.grey[100],
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 70,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? const Color(0xFF11468F).withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Container(
                          key: ValueKey(isActive ? activeIcon : icon),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isActive ? activeIcon : icon,
                            color:
                                isActive
                                    ? const Color(0xFF11468F)
                                    : Colors.grey[600],
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color:
                              isActive
                                  ? const Color(0xFF11468F)
                                  : Colors.grey[600],
                        ),
                        child: Text(label),
                      ),
                    ],
                  ),
                ),
              );
            },
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

// Alternative: Simple Bounce Animation Version
class BouncyStickyFooter extends StatelessWidget {
  final String? currentRoute;

  const BouncyStickyFooter({super.key, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final String currentRouteName =
        currentRoute ?? ModalRoute.of(context)?.settings.name ?? '';

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBouncyNavItem(
            context: context,
            icon: Icons.location_on_outlined,
            activeIcon: Icons.location_on,
            label: 'Home',
            route: '/home',
            isActive: _isRouteActive(currentRouteName, '/home'),
          ),
          _buildBouncyNavItem(
            context: context,
            icon: Icons.two_wheeler_outlined,
            activeIcon: Icons.two_wheeler,
            label: 'Vehicle',
            route: '/vehicle',
            isActive: _isRouteActive(currentRouteName, '/vehicle'),
          ),
          _buildBouncyNavItem(
            context: context,
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications,
            label: 'Alerts',
            route: '/notifications',
            isActive: _isRouteActive(currentRouteName, '/notifications'),
          ),
          _buildBouncyNavItem(
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

  Widget _buildBouncyNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.bounceOut,
        child: InkWell(
          onTap: () {
            if (!isActive) {
              Navigator.pushNamed(context, route);
            }
          },
          splashColor: Colors.grey[100],
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 70,
            decoration: BoxDecoration(
              color:
                  isActive
                      ? const Color(0xFF11468F).withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // mainSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isActive ? activeIcon : icon,
                          color: Color.lerp(
                            Colors.grey[600],
                            const Color(0xFF11468F),
                            value,
                          ),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isActive ? const Color(0xFF11468F) : Colors.grey[600],
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isRouteActive(String currentRoute, String targetRoute) {
    if (currentRoute == targetRoute) return true;

    if (targetRoute == '/vehicle' &&
        (currentRoute.startsWith('/vehicle') ||
            currentRoute.startsWith('/manage-vehicle') ||
            currentRoute.startsWith('/geofence') ||
            currentRoute.startsWith('/set-range') ||
            currentRoute.startsWith('/drive-history'))) {
      return true;
    }

    if (targetRoute == '/home' &&
        (currentRoute == '/' || currentRoute.isEmpty)) {
      return true;
    }

    return false;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../services/device/deviceService.dart';
import '../../utils/snackbar.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Common/loading_screen.dart';
import '../GeoFence/geofence.dart';
import 'geofence_edit_screen.dart';
import '../../widgets/Geofence/geofence_card.dart';
import '../../widgets/Common/confirmation_dialog.dart';

class GeofenceListScreen extends StatefulWidget {
  final String deviceId;

  const GeofenceListScreen({super.key, required this.deviceId});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen>
    with TickerProviderStateMixin {
  bool _isDeleting = false;
  late AnimationController _listAnimationController;
  final GeofenceService _geofenceService = GeofenceService();
  final DeviceService _deviceService = DeviceService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  /// Helper method to get device name by ID
  Future<String> _getDeviceName(String deviceId) async {
    try {
      final device = await _deviceService.getDeviceById(deviceId);
      return device?.name ?? 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(theme, colorScheme),
      body: _buildBody(theme, colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: colorScheme.primary,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Geofences',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: FutureBuilder<String>(
              future: _getDeviceName(widget.deviceId),
              builder: (context, snapshot) {
                final deviceName = snapshot.data ?? 'Loading...';
                return Text(
                  'Device: $deviceName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.add_rounded, color: colorScheme.primary),
          onPressed: () {
            HapticFeedback.mediumImpact();
            _navigateToCreateGeofence();
          },
          tooltip: 'Add Geofence',
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
          onPressed: () {
            HapticFeedback.lightImpact();
            _triggerRefresh();
          },
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.95)],
        ),
      ),
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        color: colorScheme.primary,
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        displacement: 40,
        child: StreamBuilder<List<Geofence>>(
          stream: _geofenceService.getGeofencesStream(widget.deviceId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildScrollableErrorCard(snapshot.error);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildScrollableLoadingScreen();
            }

            final geofences = snapshot.data ?? [];
            if (geofences.isEmpty) {
              return _buildScrollableEmptyState(theme, colorScheme);
            }

            return _buildGeofenceList(geofences);
          },
        ),
      ),
    );
  }

  // Make error card scrollable for pull-to-refresh
  Widget _buildScrollableErrorCard(dynamic error) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ErrorCard(
                message: 'Failed to load geofences: $error',
                onRetry: _triggerRefresh,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Make loading screen scrollable for pull-to-refresh
  Widget _buildScrollableLoadingScreen() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: const LoadingScreen(message: 'Loading geofences...'),
        ),
      ],
    );
  }

  // Make empty state scrollable for pull-to-refresh
  Widget _buildScrollableEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      // Clamp value to avoid opacity error
                      final safeValue = value.clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: safeValue,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(
                              0.3,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.location_searching_rounded,
                            size: 80,
                            color: colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'No geofences yet',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create your first geofence to start\nmonitoring specific locations',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pull down to refresh',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeofenceList(List<Geofence> geofences) {
    return FadeTransition(
      opacity: _listAnimationController,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final geofence = geofences[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    final safeValue = value.clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - safeValue)),
                      child: Opacity(
                        opacity: safeValue,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildDismissibleGeofenceCard(geofence),
                        ),
                      ),
                    );
                  },
                );
              }, childCount: geofences.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleGeofenceCard(Geofence geofence) {
    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: Key(geofence.id),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(),
        confirmDismiss: (_) => _showDeleteConfirmation(geofence),
        onDismissed: (_) => _deleteGeofence(geofence, geofence.name),
        child: GeofenceCard(
          geofence: geofence,
          isDeleting: _isDeleting,
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToEditGeofence(geofence);
          },
          onStatusChanged: (bool value) {
            HapticFeedback.selectionClick();
            _toggleStatus(geofence, value);
          },
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.delete, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          const Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // Handle pull-to-refresh
  Future<void> _handleRefresh() async {
    try {
      // Force refresh the geofences stream
      _triggerRefresh;

      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Geofences refreshed');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to refresh geofences: $e');
      }
    }
  }

  // Trigger refresh programmatically (for refresh button)
  void _triggerRefresh() {
    _refreshIndicatorKey.currentState?.show();
  }

  Future<bool?> _showDeleteConfirmation(Geofence geofence) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Delete Geofence',
            content: 'Are you sure you want to delete "${geofence.name}"?',
            confirmText: 'Delete',
            cancelText: 'Cancel',
            confirmColor: Colors.red,
          ),
    );
  }

  void _deleteGeofence(Geofence geofence, String name) async {
    setState(() => _isDeleting = true);

    try {
      await _geofenceService.deleteGeofence(geofence.id);
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Geofence "$name" deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to delete geofence: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _toggleStatus(Geofence geofence, bool value) async {
    try {
      final updatedGeofence = geofence.copyWith(status: value);
      await _geofenceService.updateGeofence(updatedGeofence);
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Geofence ${value ? 'activated' : 'deactivated'} successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to update status: $e');
      }
    }
  }

  void _navigateToCreateGeofence() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                GeofenceMapScreen(deviceId: widget.deviceId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToEditGeofence(Geofence geofence) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                GeofenceEditScreen(geofence: geofence),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: animation.drive(
                Tween(
                  begin: 0.95,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

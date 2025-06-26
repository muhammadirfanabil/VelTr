import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../utils/snackbar.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Common/loading_screen.dart';
import '../GeoFence/geofence.dart';
import 'geofence_edit_screen.dart';
import '../../widgets/Geofence/geofence_card.dart'; // Updated import

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
  final ScrollController _scrollController = ScrollController();

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
      // Removed floatingActionButton and floatingActionButtonLocation
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
            child: Text(
              'Device: ${widget.deviceId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
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
            setState(() {});
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
      child: StreamBuilder<List<Geofence>>(
        stream: _geofenceService.getGeofencesStream(widget.deviceId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ErrorCard(
                  message: 'Failed to load geofences: ${snapshot.error}',
                  onRetry: () => setState(() {}),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen(message: 'Loading geofences...');
          }

          final geofences = snapshot.data ?? [];
          if (geofences.isEmpty) {
            return _buildEmptyState(theme, colorScheme);
          }

          return _buildGeofenceList(geofences);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
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
                      color: colorScheme.primaryContainer.withOpacity(0.3),
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
            // Removed "Add Geofence" button here
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceList(List<Geofence> geofences) {
    return FadeTransition(
      opacity: _listAnimationController,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
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
                    // Clamp opacity to [0.0, 1.0] to avoid assertion error
                    final safeValue = value.clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, 50 * (1 - safeValue)),
                      child: Opacity(
                        opacity: safeValue,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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

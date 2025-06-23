import 'package:flutter/material.dart';
import '../../models/Geofence/Geofence.dart';
import '../../services/Geofence/geofenceService.dart';
import '../../utils/snackbar.dart';
import '../../widgets/Common/error_card.dart';
import '../../widgets/Common/loading_screen.dart';
import '../GeoFence/geofence.dart';
import 'geofence_edit_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  final String deviceId;

  const GeofenceListScreen({super.key, required this.deviceId});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  bool _isDeleting = false;
  final GeofenceService _geofenceService = GeofenceService();

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
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        children: [
          Text(
            'Geofences',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            'Device: ${widget.deviceId}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _navigateToCreateGeofence,
          tooltip: 'Add Geofence',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.2)],
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

          return _buildGeofenceList(geofences, theme, colorScheme);
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fence_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No geofences found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first geofence to monitor\nspecific locations for this device',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToCreateGeofence,
              icon: const Icon(Icons.add),
              label: const Text('Create Geofence'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceList(
    List<Geofence> geofences,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: geofences.length,
      itemBuilder: (context, index) {
        final geofence = geofences[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          child: _buildGeofenceCard(geofence, index, theme, colorScheme),
        );
      },
    );
  }

  Widget _buildGeofenceCard(
    Geofence geofence,
    int index,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final bool isActive = geofence.status;
    final String name = geofence.name;
    final String address = geofence.address ?? 'No address specified';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(geofence.id),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(colorScheme),
        confirmDismiss: (direction) => _confirmDelete(name, theme, colorScheme),
        onDismissed: (direction) => _deleteGeofence(geofence, name),
        child: Material(
          elevation: 2,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToEditGeofence(geofence),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isActive
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : colorScheme.outline.withValues(alpha: 0.1),
                  width: isActive ? 1.5 : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    isActive
                        ? Colors.blue.shade50.withValues(alpha: 0.3)
                        : colorScheme.surfaceContainerLow,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildGeofenceIcon(isActive, colorScheme),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isActive
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        isActive
                                            ? Colors.black
                                            : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusSwitch(geofence, isActive, colorScheme),
                      ],
                    ),
                    if (address.isNotEmpty &&
                        address != 'No address specified') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                address,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 226, 46, 46),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete, color: colorScheme.onError, size: 28),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: TextStyle(
              color: colorScheme.onError,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceIcon(bool isActive, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isActive
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Icon(
        Icons.fence_rounded,
        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }

  Widget _buildStatusSwitch(
    Geofence geofence,
    bool isActive,
    ColorScheme colorScheme,
  ) {
    return Transform.scale(
      scale: 0.9,
      child: Switch.adaptive(
        value: isActive,
        onChanged:
            _isDeleting ? null : (value) => _toggleStatus(geofence, value),
        activeColor: colorScheme.primary,
        activeTrackColor: colorScheme.primaryContainer,
        inactiveThumbColor: colorScheme.outline,
        inactiveTrackColor: colorScheme.surfaceContainerHigh,
      ),
    );
  }

  Future<bool?> _confirmDelete(
    String name,
    ThemeData theme,
    ColorScheme colorScheme,
  ) async {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Delete Geofence',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "$name"? This action cannot be undone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 226, 46, 46),
                  foregroundColor: colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteGeofence(Geofence geofence, String name) async {
    setState(() => _isDeleting = true);

    try {
      await _geofenceService.deleteGeofence(geofence.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showSuccess(context, 'Geofence "$name" deleted'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showError(context, 'Failed to delete geofence: $e'),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showSuccess(
            context,
            'Geofence ${value ? 'activated' : 'deactivated'} successfully',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackbarUtils.showError(context, 'Failed to update status: $e'),
        );
      }
    }
  }

  void _navigateToCreateGeofence() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeofenceMapScreen(deviceId: widget.deviceId),
      ),
    );
  }

  void _navigateToEditGeofence(Geofence geofence) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GeofenceEditScreen(geofence: geofence)),
    );
  }
}

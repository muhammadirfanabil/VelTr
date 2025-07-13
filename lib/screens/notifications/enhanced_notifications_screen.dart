import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/notifications/unified_notification.dart';
import '../../models/notifications/notification_date_group.dart';
import '../../models/vehicle/vehicle.dart';
import '../../services/notifications/unified_notification_service.dart';
import '../../services/vehicle/vehicleService.dart';
import '../../services/device/deviceService.dart';

import '../../widgets/notifications/notification_card.dart';
import '../../widgets/Common/confirmation_dialog.dart';
import '../../widgets/Common/loading_screen.dart';
import '../../widgets/Common/stickyFooter.dart';
import '../../utils/snackbar.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';

class EnhancedNotificationsScreen extends StatefulWidget {
  const EnhancedNotificationsScreen({super.key});

  @override
  State<EnhancedNotificationsScreen> createState() =>
      _EnhancedNotificationsScreenState();
}

class _EnhancedNotificationsScreenState
    extends State<EnhancedNotificationsScreen> {
  final UnifiedNotificationService _notificationService =
      UnifiedNotificationService();
  final VehicleService _vehicleService = VehicleService();
  final DeviceService _deviceService = DeviceService();
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  bool _isRefreshing = false;

  // Vehicle filter state
  List<vehicle> _availableVehicles = [];
  String? _selectedVehicleId; // null means "All Vehicles"
  bool _isLoadingVehicles = true;

  // Notification type filter state
  NotificationType? _selectedNotificationType; // null means "All Types"

  // Device name cache for filtering
  Map<String, String> _deviceIdToNameCache = {};

  final Set<String> _deletingNotifications = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVehicles();
  }

  void _onScroll() {
    if (_scrollController.offset > 20 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 20 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  /// Load available vehicles for filtering
  Future<void> _loadVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final vehicles = await _vehicleService.getVehiclesStream().first;

      // Build device cache for filtering
      final Map<String, String> deviceCache = {};
      for (final vehicle in vehicles) {
        if (vehicle.deviceId != null) {
          try {
            final deviceName = await _deviceService.getDeviceNameById(
              vehicle.deviceId!,
            );
            if (deviceName != null) {
              deviceCache[vehicle.deviceId!] = deviceName;
            }
          } catch (e) {
            debugPrint('Error getting device name for ${vehicle.deviceId}: $e');
          }
        }
      }

      setState(() {
        _availableVehicles = vehicles;
        _deviceIdToNameCache = deviceCache;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      setState(() {
        _availableVehicles = [];
        _deviceIdToNameCache = {};
        _isLoadingVehicles = false;
      });
    }
  }

  /// Filter notifications based on selected vehicle
  List<UnifiedNotification> _filterNotificationsByVehicle(
    List<UnifiedNotification> notifications,
  ) {
    if (_selectedVehicleId == null) {
      return _enhanceNotificationsWithVehicleNames(
        notifications,
      ); // Show all notifications with vehicle names
    }

    // Find the selected vehicle
    final selectedVehicle = _availableVehicles.firstWhere(
      (vehicle) => vehicle.id == _selectedVehicleId,
      orElse:
          () => vehicle(
            id: '',
            name: '',
            ownerId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );

    if (selectedVehicle.name.isEmpty || selectedVehicle.deviceId == null) {
      print('⚠️ [FILTER] Vehicle has no name or deviceId: ${selectedVehicle.name}, ${selectedVehicle.deviceId}');
      return []; // Vehicle not found or has no device, show no notifications
    }

    // Get the device name for this vehicle from cache
    final vehicleDeviceName = _deviceIdToNameCache[selectedVehicle.deviceId];
    if (vehicleDeviceName == null) {
      print('⚠️ [FILTER] Device name not found in cache for deviceId: ${selectedVehicle.deviceId}');
      print('🔍 [FILTER] Available device cache: $_deviceIdToNameCache');
      return []; // Device name not found, show no notifications
    }

    print('🔍 [FILTER] Filtering for vehicle: ${selectedVehicle.name}, deviceId: ${selectedVehicle.deviceId}, deviceName: $vehicleDeviceName');

    // Filter notifications by matching device name
    final filteredNotifications =
        notifications.where((notification) {
          print('🔎 [FILTER] Checking notification: ${notification.type}, id: ${notification.id}');
          print('🔎 [FILTER] - notification.deviceName: ${notification.deviceName}');
          print('🔎 [FILTER] - notification.data: ${notification.data}');
          
          // Primary check: notification deviceName matches vehicle's device name
          if (notification.deviceName != null) {
            final matches = notification.deviceName == vehicleDeviceName;
            print('🔎 [FILTER] Primary check - deviceName match: $matches');
            if (matches) return true;
          }

          // Secondary check: check data fields for device references
          final data = notification.data;
          if (data['deviceName'] != null) {
            final matches = data['deviceName'].toString() == vehicleDeviceName;
            print('🔎 [FILTER] Secondary check - data deviceName match: $matches');
            if (matches) return true;
          }

          // Tertiary check: check for deviceId in data (Firestore device ID)
          if (data['deviceId'] != null) {
            final matches = data['deviceId'].toString() == selectedVehicle.deviceId;
            print('🔎 [FILTER] Tertiary check - deviceId match: $matches');
            if (matches) return true;
          }

          // Quaternary check: for vehicle status notifications, check vehicleName
          if (notification.type == NotificationType.vehicleStatus && 
              data['vehicleName'] != null) {
            // If the vehicle name in notification matches selected vehicle name
            final matches = data['vehicleName'].toString() == selectedVehicle.name;
            print('🔎 [FILTER] Quaternary check - vehicleName match: $matches');
            if (matches) return true;
          }

          // Quinary check: check if deviceIdentifier matches (from Cloud Function)
          if (data['deviceIdentifier'] != null) {
            final matches = data['deviceIdentifier'].toString() == vehicleDeviceName;
            print('🔎 [FILTER] Quinary check - deviceIdentifier match: $matches');
            if (matches) return true;
          }

          print('❌ [FILTER] No match found for notification ${notification.id}');
          // No matching device reference found
          return false;
        }).toList();

    print('✅ [FILTER] Filtered ${filteredNotifications.length} notifications from ${notifications.length} total');

    return _enhanceNotificationsWithVehicleNames(filteredNotifications);
  }

  /// Filter notifications based on selected notification type
  List<UnifiedNotification> _filterNotificationsByType(
    List<UnifiedNotification> notifications,
  ) {
    if (_selectedNotificationType == null) {
      return notifications; // Show all types
    }

    return notifications.where((notification) {
      return notification.type == _selectedNotificationType;
    }).toList();
  }

  /// Enhance notifications by replacing device names with vehicle names
  /// Changes "BOA7322B2EC4 has entered Teluk Dalam Geofence"
  /// to "My Car(BOA7322B2EC4) has entered Teluk Dalam Geofence"
  List<UnifiedNotification> _enhanceNotificationsWithVehicleNames(
    List<UnifiedNotification> notifications,
  ) {
    return notifications.map((notification) {
      // Find the vehicle that owns this device
      vehicle? owningVehicle;
      String? deviceName =
          notification.deviceName ??
          notification.data['deviceName']?.toString();

      if (deviceName != null) {
        // Find vehicle by matching device name in cache
        for (final vehicle in _availableVehicles) {
          if (vehicle.deviceId != null &&
              _deviceIdToNameCache[vehicle.deviceId] == deviceName) {
            owningVehicle = vehicle;
            break;
          }
        }
      }

      if (owningVehicle != null && deviceName != null) {
        // Create enhanced message with vehicle name
        String enhancedMessage = notification.message;
        String enhancedTitle = notification.title;

        // Replace device name with vehicle(device) format in message
        enhancedMessage = enhancedMessage.replaceAll(
          deviceName,
          '${owningVehicle.name} ($deviceName)',
        );

        // Also update title if it contains the device name
        if (enhancedTitle.contains(deviceName)) {
          enhancedTitle = enhancedTitle.replaceAll(
            deviceName,
            '${owningVehicle.name}($deviceName)',
          );
        }

        // Create a new notification with the enhanced message and title
        return UnifiedNotification(
          id: notification.id,
          type: notification.type,
          title: enhancedTitle,
          message: enhancedMessage,
          timestamp: notification.timestamp,
          data: notification.data,
          isRead: notification.isRead,
          geofenceAction: notification.geofenceAction,
          deviceName: notification.deviceName,
          geofenceName: notification.geofenceName,
          latitude: notification.latitude,
          longitude: notification.longitude,
        );
      }

      return notification; // Return original if no vehicle found
    }).toList();
  }

  /// Apply both vehicle and type filters
  List<UnifiedNotification> _applyAllFilters(
    List<UnifiedNotification> notifications,
  ) {
    var filtered = notifications;
    
    // Apply vehicle filter
    filtered = _filterNotificationsByVehicle(filtered);
    
    // Apply type filter
    filtered = _filterNotificationsByType(filtered);
    
    return filtered;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.backgroundPrimary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark
                    ? [
                      AppColors.darkBackground,
                      AppColors.darkBackground.withValues(alpha: 0.93),
                    ]
                    : [
                      Colors.white,
                      Colors.blue.shade50.withValues(alpha: 0.2),
                    ],
            stops: const [0.7, 1.0],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(theme, isDark),
            _buildNotificationsContent(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      snap: true,
      elevation: _isScrolled ? 0.5 : 0,
      shadowColor:
          isDark ? Colors.black.withValues(alpha: 0.2) : Colors.transparent,
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.backgroundPrimary,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? AppColors.primaryBlue : AppColors.primaryBlue,
          ),
          onPressed:
              () => Navigator.pushReplacementNamed(
                context,
                AppConstants.trackVehicleRoute,
              ),
          padding: EdgeInsets.zero,
          splashRadius: 22,
          tooltip: "Back",
        ),
      ),
      title: Text(
        'Notifications',
        style: theme.textTheme.titleLarge?.copyWith(
          color: isDark ? AppColors.textPrimary : AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        // Refresh button
        Padding(
          padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
          child: IconButton(
            onPressed: _isRefreshing ? null : _refreshNotifications,
            icon:
                _isRefreshing
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    )
                    : Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
            padding: EdgeInsets.zero,
            splashRadius: 22,
            tooltip: 'Refresh',
          ),
        ),

        // Clear all button
        StreamBuilder<List<UnifiedNotification>>(
          stream: _notificationService.getNotificationsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: IconButton(
                  onPressed: () => _showClearAllConfirmation(context),
                  icon: Icon(
                    AppIcons.notificationClear,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 22,
                  tooltip: 'Clear all',
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildVehicleFilter(ThemeData theme, bool isDark) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.backgroundPrimary,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black).withValues(
              alpha: 0.05,
            ),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter title
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 8,
            ),
            child: Text(
              'Filter by Vehicle',
              style: theme.textTheme.titleSmall?.copyWith(
                color:
                    isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Vehicle selector
          Expanded(
            child:
                _isLoadingVehicles
                    ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : _buildVehicleSelector(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector(ThemeData theme, bool isDark) {
    // Filter vehicles to only show those with devices, but still show "All Vehicles"
    final vehiclesWithDevices =
        _availableVehicles
            .where(
              (vehicle) =>
                  vehicle.deviceId != null &&
                  _deviceIdToNameCache.containsKey(vehicle.deviceId),
            )
            .toList();

    // Create list with "All Vehicles" option first, then vehicles with devices
    final vehicleOptions = [
      {'id': null, 'name': 'All Vehicles', 'hasDevice': true},
      ...vehiclesWithDevices.map(
        (vehicle) => {
          'id': vehicle.id,
          'name': vehicle.name,
          'hasDevice': true, // All filtered vehicles have devices
        },
      ),
      // Show vehicles without devices at the end with different styling
      ..._availableVehicles
          .where(
            (vehicle) =>
                vehicle.deviceId == null ||
                !_deviceIdToNameCache.containsKey(vehicle.deviceId),
          )
          .map(
            (vehicle) => {
              'id': vehicle.id,
              'name': vehicle.name,
              'hasDevice': false,
            },
          ),
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: vehicleOptions.length,
      itemBuilder: (context, index) {
        final option = vehicleOptions[index];
        final isSelected = option['id'] == _selectedVehicleId;
        final hasDevice = option['hasDevice'] as bool;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedVehicleId = option['id'] as String?;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.primaryBlue
                      : (isDark
                          ? AppColors.darkSurfaceElevated
                          : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.primaryBlue
                        : (isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300),
                width: 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option['id'] == null) ...[
                  Icon(
                    Icons.all_inclusive_rounded,
                    size: 16,
                    color:
                        isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.textSecondary
                                : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  Icon(
                    hasDevice
                        ? Icons.two_wheeler_rounded
                        : Icons.two_wheeler_outlined,
                    size: 16,
                    color:
                        isSelected
                            ? Colors.white
                            : (hasDevice
                                ? (isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey.shade600)
                                : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.grey.shade400)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  option['name'] as String,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Colors.white
                            : (hasDevice
                                ? (isDark
                                    ? AppColors.textPrimary
                                    : Colors.black87)
                                : (isDark
                                    ? AppColors.textTertiary
                                    : Colors.grey.shade500)),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                // Show device indicator for vehicles without devices
                if (option['id'] != null && !hasDevice) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.warning_rounded,
                    size: 12,
                    color:
                        isSelected
                            ? Colors.white70
                            : (isDark
                                ? AppColors.textTertiary
                                : Colors.orange.shade400),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTypeFilter(ThemeData theme, bool isDark) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.backgroundPrimary,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black).withValues(
              alpha: 0.05,
            ),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter title
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 8,
            ),
            child: Text(
              'Filter by Type',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isDark ? AppColors.textSecondary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Type selector
          Expanded(
            child: _buildNotificationTypeSelector(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTypeSelector(ThemeData theme, bool isDark) {
    final typeOptions = [
      {'type': null, 'name': 'All Types', 'icon': Icons.notifications_rounded},
      {'type': NotificationType.vehicleStatus, 'name': 'Vehicle Status', 'icon': Icons.power_settings_new_rounded},
      {'type': NotificationType.geofence, 'name': 'Geofence Alerts', 'icon': Icons.location_on_rounded},
      {'type': NotificationType.system, 'name': 'System', 'icon': Icons.settings_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: typeOptions.map((option) {
          final isSelected = _selectedNotificationType == option['type'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textSecondary : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    option['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.textSecondary : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              selectedColor: AppColors.primaryBlue,
              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.backgroundSecondary,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? AppColors.darkBorder : AppColors.border),
                width: 1,
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedNotificationType = selected ? option['type'] as NotificationType? : null;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationsContent(ThemeData theme, bool isDark) {
    return SliverFillRemaining(
      child: Container(
        color: isDark ? AppColors.darkBackground : AppColors.backgroundPrimary,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshNotifications,
                color: AppColors.primaryBlue,
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                strokeWidth: 2.2,
                child: StreamBuilder<List<UnifiedNotification>>(
                  stream: _notificationService.getNotificationsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !_isRefreshing) {
                      return Column(
                        children: [
                          _buildVehicleFilter(theme, isDark),
                          _buildNotificationTypeFilter(theme, isDark),
                          const Expanded(
                            child: LoadingScreen(message: 'Loading alerts...'),
                          ),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          _buildVehicleFilter(theme, isDark),
                          _buildNotificationTypeFilter(theme, isDark),
                          Expanded(
                            child: _buildErrorState(theme, isDark),
                          ),
                        ],
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Column(
                        children: [
                          _buildVehicleFilter(theme, isDark),
                          _buildNotificationTypeFilter(theme, isDark),
                          Expanded(
                            child: _buildEmptyState(theme, isDark),
                          ),
                        ],
                      );
                    }

                    // Apply both vehicle and type filters
                    final filteredNotifications = _applyAllFilters(snapshot.data!);

                    if (filteredNotifications.isEmpty &&
                        (_selectedVehicleId != null || _selectedNotificationType != null)) {
                      return Column(
                        children: [
                          _buildVehicleFilter(theme, isDark),
                          _buildNotificationTypeFilter(theme, isDark),
                          Expanded(
                            child: _buildNoNotificationsForFilters(theme, isDark),
                          ),
                        ],
                      );
                    }

                    final groups = NotificationDateGroup.createGroups(
                      filteredNotifications,
                    );
                    return _buildNotificationsListWithFilter(groups, theme, isDark);
                  },
                ),
              ),
            ),
            const StickyFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(37),
                    ),
                    child: Icon(
                      AppIcons.error,
                      size: 36,
                      color:
                          isDark
                              ? AppColors.textTertiary
                              : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We couldn\'t load your Alerts.\nPull down to refresh or tap the refresh button.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                      fontSize: 14.5,
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

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(43),
                    ),
                    child: Icon(
                      AppIcons.notificationBell,
                      size: 40,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'No Notifications Yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    'When you get notifications about your GPS tracking, they\'ll appear here.\n\nPull down to refresh.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontSize: 14.5,
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

  Widget _buildNoNotificationsForFilters(ThemeData theme, bool isDark) {
    String filterText = '';
    if (_selectedVehicleId != null && _selectedNotificationType != null) {
      final vehicleName = _availableVehicles
          .firstWhere((v) => v.id == _selectedVehicleId)
          .name;
      final typeName = _selectedNotificationType!.displayName;
      filterText = 'for $vehicleName ($typeName)';
    } else if (_selectedVehicleId != null) {
      final vehicleName = _availableVehicles
          .firstWhere((v) => v.id == _selectedVehicleId)
          .name;
      filterText = 'for $vehicleName';
    } else if (_selectedNotificationType != null) {
      filterText = 'for ${_selectedNotificationType!.displayName}';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 64,
            color: isDark ? AppColors.textTertiary : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications $filterText',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or check back later',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedVehicleId = null;
                _selectedNotificationType = null;
              });
            },
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Clear Filters'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsListWithFilter(
    List<NotificationDateGroup> groups,
    ThemeData theme,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, bottom: 104),
      itemCount: groups.length + 2, // +2 for the filters at the top
      itemBuilder: (context, index) {
        // First two items are the filters
        if (index == 0) {
          return _buildVehicleFilter(theme, isDark);
        }
        if (index == 1) {
          return _buildNotificationTypeFilter(theme, isDark);
        }
        
        // Adjust index for the actual groups
        final groupIndex = index - 2;
        final group = groups[groupIndex];
        return _buildDateGroup(group, theme, isDark, groupIndex == 0, groups);
      },
    );
  }

  Widget _buildDateGroup(
    NotificationDateGroup group,
    ThemeData theme,
    bool isDark,
    bool isFirst,
    List<NotificationDateGroup> allGroups,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header with minimalist pill style
        Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: isFirst ? 18 : 32,
            bottom: 7,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  group.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (group.unreadCount > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.unreadCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Notifications list
        ...group.notifications.asMap().entries.map((entry) {
          final index = entry.key;
          final notification = entry.value;

          // Hide notifications that are being deleted to prevent Dismissible error
          if (_deletingNotifications.contains(notification.id)) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
            child: NotificationCard(
              key: ValueKey(notification.id),
              notification: notification,
              onDelete: () => _deleteNotification(notification),
              showTimestamp: _shouldShowTimestamp(
                notification,
                index > 0 ? group.notifications[index - 1] : null,
              ),
            ),
          );
        }),

        // Subtle divider after each group
        if (allGroups.indexOf(group) < allGroups.length - 1)
          Container(
            margin: const EdgeInsets.only(top: 14),
            height: 1,
            color:
                isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.13)
                    : AppColors.backgroundSecondary,
          ),
      ],
    );
  }

  bool _shouldShowTimestamp(
    UnifiedNotification notification,
    UnifiedNotification? previousNotification,
  ) {
    if (previousNotification == null) return true;
    final currentTime = notification.timestamp;
    final previousTime = previousNotification.timestamp;
    return currentTime.difference(previousTime).inHours >= 2;
  }

  Future<void> _deleteNotification(UnifiedNotification notification) async {
    if (_deletingNotifications.contains(notification.id)) {
      return;
    }
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Notification',
      content:
          'Are you sure you want to delete this notification? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );
    if (confirmed == true && mounted) {
      setState(() {
        _deletingNotifications.add(notification.id);
      });
      try {
        await _notificationService.deleteNotification(notification);
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Notification deleted');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _deletingNotifications.remove(notification.id);
          });
          SnackbarUtils.showError(context, 'Failed to delete notification');
        }
      } finally {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _deletingNotifications.remove(notification.id);
              });
            }
          });
        }
      }
    }
  }

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
      // Refresh both notifications and vehicles
      await Future.wait([
        _notificationService.refreshNotifications(),
        _loadVehicles(),
      ]);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Alerts refreshed');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to refresh Alerts');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _showClearAllConfirmation(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Clear All Notifications',
      content:
          'This will permanently delete all your notifications. This action can\'t be undone.',
      confirmText: 'Clear All',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );
    if (confirmed == true && mounted) {
      try {
        await _notificationService.clearAllNotifications();
        setState(() {
          _deletingNotifications.clear();
        });
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'All notifications cleared');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to clear notifications');
        }
      }
    }
  }
}

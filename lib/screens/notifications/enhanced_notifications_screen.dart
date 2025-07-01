import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/notifications/unified_notification.dart';
import '../../models/notifications/notification_date_group.dart';
import '../../services/notifications/unified_notification_service.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  bool _isRefreshing = false;

  final Set<String> _deletingNotifications = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 20 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 20 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
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
                      return const LoadingScreen(message: 'Loading alerts...');
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(theme, isDark);
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState(theme, isDark);
                    }

                    final groups = NotificationDateGroup.createGroups(
                      snapshot.data!,
                    );
                    return _buildNotificationsList(groups, theme, isDark);
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

  Widget _buildNotificationsList(
    List<NotificationDateGroup> groups,
    ThemeData theme,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 104),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildDateGroup(group, theme, isDark, index == 0, groups);
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
      await _notificationService.refreshNotifications();
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

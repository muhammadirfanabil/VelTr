import 'package:flutter/material.dart';
import '../../services/history/history_service.dart';
import '../../theme/app_colors.dart';

class HistoryStatisticsWidget extends StatefulWidget {
  final List<HistoryEntry> historyEntries;

  const HistoryStatisticsWidget({super.key, required this.historyEntries});

  @override
  State<HistoryStatisticsWidget> createState() =>
      _HistoryStatisticsWidgetState();
}

class _HistoryStatisticsWidgetState extends State<HistoryStatisticsWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.historyEntries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final stats = HistoryService.getDrivingStatistics(widget.historyEntries);
    final totalDistance = stats['totalDistance'] as double;
    final totalPoints = stats['totalPoints'] as int;
    // final timeSpan = stats['timeSpan'] as Duration; // Disabled for now

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      color: AppColors.surface,
      child: Column(
        children: [
          // Accordion Header - Always visible
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Driving Statistics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  // Summary when collapsed
                  if (!_isExpanded) ...[
                    Text(
                      '${totalDistance.toStringAsFixed(1)}m • $totalPoints pts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accordion Content - Expandable
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.only(left: 18, right: 18, bottom: 15),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.straighten_rounded,
                          label: 'Distance',
                          value: '${totalDistance.toStringAsFixed(1)} m',
                          color: AppColors.primaryBlue,
                          theme: theme,
                        ),
                      ),
                      // Duration statistic disabled as requested
                      // Expanded(
                      //   child: _buildStatItem(
                      //     icon: Icons.access_time_rounded,
                      //     label: 'Duration',
                      //     value: _formatDuration(timeSpan),
                      //     color: AppColors.success,
                      //     theme: theme,
                      //   ),
                      // ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.location_on_rounded,
                          label: 'Points',
                          value: '$totalPoints',
                          color: AppColors.warning,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.2,
          ),
        ),
      ],
    );
  }

  // Duration formatting method - disabled for now
  // String _formatDuration(Duration duration) {
  //   final hours = duration.inHours;
  //   final minutes = duration.inMinutes.remainder(60);

  //   if (hours > 0) {
  //     return '${hours}h ${minutes}m';
  //   } else if (minutes > 0) {
  //     return '${minutes}m';
  //   } else {
  //     return '< 1m';
  //   }
  // }
}

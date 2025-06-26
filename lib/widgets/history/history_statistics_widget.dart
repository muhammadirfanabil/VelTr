import 'package:flutter/material.dart';
import '../../services/history/history_service.dart';
import '../../theme/app_colors.dart';

class HistoryStatisticsWidget extends StatelessWidget {
  final List<HistoryEntry> historyEntries;

  const HistoryStatisticsWidget({super.key, required this.historyEntries});

  @override
  Widget build(BuildContext context) {
    if (historyEntries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final stats = HistoryService.getDrivingStatistics(historyEntries);
    final totalDistance = stats['totalDistance'] as double;
    final totalPoints = stats['totalPoints'] as int;
    final timeSpan = stats['timeSpan'] as Duration;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driving Statistics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 15.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: '${totalDistance.toStringAsFixed(1)} km',
                    color: AppColors.primaryBlue,
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.access_time_rounded,
                    label: 'Duration',
                    value: _formatDuration(timeSpan),
                    color: AppColors.success,
                    theme: theme,
                  ),
                ),
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
            color: color.withOpacity(0.11),
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '< 1m';
    }
  }
}

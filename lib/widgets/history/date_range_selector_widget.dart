import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DateRangeSelectorWidget extends StatelessWidget {
  final int selectedDays;
  final List<int> dayOptions;
  final Function(int) onDaysChanged;

  const DateRangeSelectorWidget({
    super.key,
    required this.selectedDays,
    required this.dayOptions,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
      decoration: BoxDecoration(color: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Show history for',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 15.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(dayOptions.length, (idx) {
              final isSelected = selectedDays == dayOptions[idx];
              return Padding(
                padding: EdgeInsets.only(
                  right: idx == dayOptions.length - 1 ? 0 : 8,
                ),
                child: ChoiceChip(
                  label: Text(
                    dayOptions[idx] == 1 ? '1 Day' : '${dayOptions[idx]} Days',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? Colors.white
                              : AppColors.textPrimary.withValues(alpha: 0.72),
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onDaysChanged(dayOptions[idx]),
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.backgroundSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: isSelected ? 1.5 : 0,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

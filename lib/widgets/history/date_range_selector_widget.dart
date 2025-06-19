import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Show history for',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: dayOptions.map((days) => selectedDays == days).toList(),
            onPressed: (index) {
              final selectedDaysValue = dayOptions[index];
              onDaysChanged(selectedDaysValue);
            },
            borderRadius: BorderRadius.circular(8),
            selectedBorderColor: Colors.blue[600],
            selectedColor: Colors.white,
            fillColor: Colors.blue[600],
            color: Colors.grey[700],
            borderColor: Colors.grey[300],
            borderWidth: 1.5,
            constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '1 Day',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '3 Days',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '7 Days',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

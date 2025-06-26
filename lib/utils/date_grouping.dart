import 'package:intl/intl.dart';

class DateGrouping {
  static String getGroupTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(today.year, today.month - 1, today.day);

    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) {
      return 'Today';
    } else if (dateToCompare == yesterday) {
      return 'Yesterday';
    } else if (dateToCompare.isAfter(weekAgo)) {
      return 'This Week';
    } else if (dateToCompare.isAfter(monthAgo)) {
      return 'This Month';
    } else if (dateToCompare.year == today.year) {
      return DateFormat('MMMM').format(date);
    } else {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  static int compareGroups(String group1, String group2) {
    final orderMap = {
      'Today': 0,
      'Yesterday': 1,
      'This Week': 2,
      'This Month': 3,
    };

    final order1 = orderMap[group1] ?? 4;
    final order2 = orderMap[group2] ?? 4;

    if (order1 != order2) {
      return order1.compareTo(order2);
    }

    // If both are in the same category (e.g., both are months),
    // compare them as dates
    if (order1 == 4) {
      try {
        final date1 = DateFormat('MMMM yyyy').parse(group1);
        final date2 = DateFormat('MMMM yyyy').parse(group2);
        return date2.compareTo(date1); // Most recent first
      } catch (_) {
        return group1.compareTo(group2);
      }
    }

    return 0;
  }
}

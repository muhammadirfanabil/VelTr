import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../../services/history/history_service.dart';
import '../../theme/app_colors.dart';

enum SortOrder { newest, oldest }

class HistoryListWidget extends StatefulWidget {
  final List<HistoryEntry> historyEntries;
  final bool isLoading;
  final String? error;

  const HistoryListWidget({
    super.key,
    required this.historyEntries,
    required this.isLoading,
    this.error,
  });

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  final Map<String, String> _addressCache = {};
  SortOrder _currentSortOrder = SortOrder.newest;

  Future<String> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final key = '$latitude,$longitude';

    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];

        String address = '';
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address += placemark.street!;
        }
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += placemark.subLocality!;
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += placemark.locality!;
        }

        if (address.isEmpty && placemark.administrativeArea != null) {
          address = placemark.administrativeArea!;
        }

        if (address.isEmpty) {
          address = 'Unknown location';
        }

        _addressCache[key] = address;
        return address;
      }
    } catch (e) {
      // ignore geocoding errors
    }

    final fallback =
        'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    _addressCache[key] = fallback;
    return fallback;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');

    if (entryDate == today) {
      return 'Today at ${timeFormat.format(dateTime)}';
    } else if (entryDate == yesterday) {
      return 'Yesterday at ${timeFormat.format(dateTime)}';
    } else {
      return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
    }
  }

  List<HistoryEntry> _getSortedHistoryEntries() {
    final sortedEntries = List<HistoryEntry>.from(widget.historyEntries);

    switch (_currentSortOrder) {
      case SortOrder.newest:
        sortedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOrder.oldest:
        sortedEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return sortedEntries;
  }

  Widget _buildSortDropdown() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SortOrder>(
                value: _currentSortOrder,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: AppColors.surface,
                onChanged: (SortOrder? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentSortOrder = newValue;
                    });
                  }
                },
                items: const [
                  DropdownMenuItem<SortOrder>(
                    value: SortOrder.newest,
                    child: Row(
                      children: [Text('Newest First'), SizedBox(width: 8)],
                    ),
                  ),
                  DropdownMenuItem<SortOrder>(
                    value: SortOrder.oldest,
                    child: Row(
                      children: [Text('Oldest First'), SizedBox(width: 8)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 12),
            Text(
              'Loading driving history...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 46, color: AppColors.error),
            const SizedBox(height: 14),
            Text(
              'Error loading history',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.historyEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 46, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              'No driving history found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Start driving to see your history here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final sortedEntries = _getSortedHistoryEntries();

    return Column(
      children: [
        _buildSortDropdown(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];

              return Card(
                margin: EdgeInsets.zero,
                elevation: 0.7,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _getAddressFromCoordinates(
                          entry.latitude,
                          entry.longitude,
                        ),
                        builder: (context, snapshot) {
                          String displayText;
                          Widget leadingIcon;

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            displayText = 'Loading address...';
                            leadingIcon = const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryBlue,
                                ),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            displayText =
                                'In ${entry.latitude.toStringAsFixed(6)}, ${entry.longitude.toStringAsFixed(6)}';
                            leadingIcon = Container(
                              width: 11,
                              height: 11,
                              decoration: const BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            );
                          } else {
                            displayText =
                                'In ${snapshot.data ?? 'Unknown location'}';
                            leadingIcon = Container(
                              width: 11,
                              height: 11,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            );
                          }
                          return Row(
                            children: [
                              leadingIcon,
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  displayText,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.7,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDateTime(entry.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

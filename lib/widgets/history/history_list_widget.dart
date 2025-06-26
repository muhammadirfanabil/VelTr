import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/history/history_service.dart';
import '../../theme/app_colors.dart';

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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      itemCount: widget.historyEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = widget.historyEntries[index];

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0.7,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            child: FutureBuilder<String>(
              future: _getAddressFromCoordinates(
                entry.latitude,
                entry.longitude,
              ),
              builder: (context, snapshot) {
                String displayText;
                Widget leadingIcon;

                if (snapshot.connectionState == ConnectionState.waiting) {
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
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  );
                } else {
                  displayText = 'In ${snapshot.data ?? 'Unknown location'}';
                  leadingIcon = Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
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
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
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
  final Map<String, bool> _isLoadingAddress = {};
  final Map<String, int> _retryCount = {};
  static const int maxRetries = 2;

  Future<String> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final key = '$latitude,$longitude';

    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    // Prevent multiple simultaneous requests for the same location
    if (_isLoadingAddress[key] == true) {
      // Wait a bit and check cache again
      await Future.delayed(const Duration(milliseconds: 500));
      if (_addressCache.containsKey(key)) {
        return _addressCache[key]!;
      }
    }

    _isLoadingAddress[key] = true;
    final currentRetry = _retryCount[key] ?? 0;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];

        // Build comprehensive address components
        List<String> addressParts = [];

        // Add street or thoroughfare
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        } else if (placemark.thoroughfare != null &&
            placemark.thoroughfare!.isNotEmpty) {
          addressParts.add(placemark.thoroughfare!);
        }

        // Add sub-thoroughfare (building number)
        if (placemark.subThoroughfare != null &&
            placemark.subThoroughfare!.isNotEmpty) {
          if (addressParts.isNotEmpty) {
            addressParts[addressParts.length - 1] =
                '${addressParts.last} ${placemark.subThoroughfare!}';
          } else {
            addressParts.add(placemark.subThoroughfare!);
          }
        }

        // Add neighborhood/sublocality
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }

        // Add locality/city district
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }

        // Add sub-administrative area (district/kecamatan)
        if (placemark.subAdministrativeArea != null &&
            placemark.subAdministrativeArea!.isNotEmpty) {
          addressParts.add(placemark.subAdministrativeArea!);
        }

        // Add administrative area (city/kabupaten)
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }

        // Add country
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          addressParts.add(placemark.country!);
        }

        // Add postal code if available
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          if (addressParts.isNotEmpty) {
            addressParts[addressParts.length - 1] =
                '${addressParts.last} ${placemark.postalCode!}';
          } else {
            addressParts.add(placemark.postalCode!);
          }
        }

        String fullAddress = addressParts.join(', ');

        // Validate that we have a meaningful address (not just plus codes or coordinates)
        if (_isValidFullAddress(fullAddress)) {
          _addressCache[key] = fullAddress;
          _isLoadingAddress[key] = false;
          return fullAddress;
        }

        // If the address seems incomplete, try with a different approach
        String fallbackAddress = _buildFallbackAddress(placemark);
        if (_isValidFullAddress(fallbackAddress)) {
          _addressCache[key] = fallbackAddress;
          _isLoadingAddress[key] = false;
          return fallbackAddress;
        }
      }
    } catch (e) {
      print('Geocoding error for coordinates ($latitude, $longitude): $e');

      // Retry mechanism
      if (currentRetry < maxRetries) {
        _retryCount[key] = currentRetry + 1;
        _isLoadingAddress[key] = false;

        // Wait before retry
        await Future.delayed(Duration(milliseconds: 1000 * (currentRetry + 1)));
        return _getAddressFromCoordinates(latitude, longitude);
      }
    }

    // Final fallback to coordinates
    _isLoadingAddress[key] = false;
    final coordinateFallback =
        'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    _addressCache[key] = coordinateFallback;
    return coordinateFallback;
  }

  /// Validates if the address is complete and user-friendly
  bool _isValidFullAddress(String address) {
    if (address.isEmpty) return false;

    // Check for plus codes or incomplete addresses
    final plusCodePattern = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}');
    if (plusCodePattern.hasMatch(address)) return false;

    // Check if address contains only coordinates
    final coordPattern = RegExp(r'^-?\d+\.?\d*,?\s*-?\d+\.?\d*$');
    if (coordPattern.hasMatch(address.replaceAll(RegExp(r'[^\d.,-]'), '')))
      return false;

    // Ensure address has at least 2 meaningful components
    final parts =
        address
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (parts.length < 2) return false;

    // Check for minimum meaningful content
    final meaningfulParts =
        parts
            .where(
              (part) =>
                  part.length > 1 &&
                  !RegExp(r'^\d+$').hasMatch(part) && // Not just numbers
                  !RegExp(r'^[A-Z0-9+]+$').hasMatch(part), // Not plus codes
            )
            .toList();

    return meaningfulParts.length >= 2;
  }

  /// Builds a fallback address from available placemark data
  String _buildFallbackAddress(Placemark placemark) {
    List<String> parts = [];

    // Prioritize more specific location info
    if (placemark.name != null &&
        placemark.name!.isNotEmpty &&
        !_isPlusCode(placemark.name!)) {
      parts.add(placemark.name!);
    }

    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }

    if (placemark.subAdministrativeArea != null &&
        placemark.subAdministrativeArea!.isNotEmpty) {
      parts.add(placemark.subAdministrativeArea!);
    }

    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      parts.add(placemark.administrativeArea!);
    }

    return parts.join(', ');
  }

  /// Checks if a string is a plus code
  bool _isPlusCode(String text) {
    final plusCodePattern = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}');
    return plusCodePattern.hasMatch(text);
  }

  /// Formats a long address for better display in the UI
  String _formatAddressForDisplay(String address) {
    if (address.length <= 60) {
      return address;
    }

    // Split by comma and take the most important parts
    final parts = address.split(', ').map((e) => e.trim()).toList();

    if (parts.length <= 2) {
      return address;
    }

    // For very long addresses, show first 2-3 most specific parts + last part (usually country)
    List<String> displayParts = [];

    // Add first part (usually street or specific location)
    if (parts.isNotEmpty) {
      displayParts.add(parts[0]);
    }

    // Add second part if it's different from first
    if (parts.length > 1 && parts[1] != parts[0]) {
      displayParts.add(parts[1]);
    }

    // Add last significant administrative area
    if (parts.length > 3) {
      final lastPart = parts[parts.length - 2]; // Usually province/state
      if (lastPart.isNotEmpty &&
          !displayParts.any((part) => part.contains(lastPart))) {
        displayParts.add(lastPart);
      }
    }

    String formatted = displayParts.join(', ');

    // If still too long, truncate intelligently
    if (formatted.length > 80) {
      if (displayParts.length > 1) {
        formatted = '${displayParts[0]}, ${displayParts.last}';
      } else {
        formatted = '${formatted.substring(0, 77)}...';
      }
    }

    return formatted;
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

  /// Shows a dialog with the full address details
  void _showFullAddressDialog(BuildContext context, HistoryEntry entry) {
    _getAddressFromCoordinates(entry.latitude, entry.longitude).then((address) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Location Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Full Address:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: SelectableText(
                      address,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Coordinates:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: SelectableText(
                      'Latitude: ${entry.latitude.toStringAsFixed(6)}\nLongitude: ${entry.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Timestamp:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      _formatDateTime(entry.createdAt),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    });
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showFullAddressDialog(context, entry),
                  child: FutureBuilder<String>(
                    future: _getAddressFromCoordinates(
                      entry.latitude,
                      entry.longitude,
                    ),
                    builder: (context, snapshot) {
                      String displayText;
                      Widget leadingIcon;
                      Color textColor = AppColors.textPrimary;

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
                        textColor = AppColors.textSecondary;
                      } else if (snapshot.hasError) {
                        displayText =
                            'Location: ${entry.latitude.toStringAsFixed(6)}, ${entry.longitude.toStringAsFixed(6)}';
                        leadingIcon = Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        );
                        textColor = AppColors.textSecondary;
                      } else {
                        final rawAddress = snapshot.data ?? 'Unknown location';
                        final formattedAddress = _formatAddressForDisplay(
                          rawAddress,
                        );

                        // Determine if this is a complete address or fallback
                        final isCompleteAddress = _isValidFullAddress(
                          rawAddress,
                        );

                        if (isCompleteAddress) {
                          displayText = formattedAddress;
                          leadingIcon = Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          );
                        } else {
                          displayText = formattedAddress;
                          leadingIcon = Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          );
                          textColor = AppColors.textSecondary;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: leadingIcon,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayText,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.7,
                                            color: textColor,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.hasData &&
                                        snapshot.data != displayText) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to view full address',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: AppColors.primaryBlue,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
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
    );
  }
}

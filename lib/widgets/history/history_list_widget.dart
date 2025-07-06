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
  final Map<String, String> _addressCache = {}; // Cache full addresses
  final Map<String, bool> _isLoadingAddress = {};
  final Map<String, int> _retryCount = {};
  static const int maxRetries = 2;

  Future<String> _getFullAddressFromCoordinates(
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

        // Build detailed Indonesian-style address
        final fullAddress = _buildCompleteIndonesianAddress(placemark);

        if (fullAddress.isNotEmpty && _isValidFullAddress(fullAddress)) {
          _addressCache[key] = fullAddress;
          _isLoadingAddress[key] = false;
          return fullAddress;
        }

        // If primary approach fails, try fallback
        final fallbackAddress = _buildFallbackCompleteAddress(placemark);
        if (fallbackAddress.isNotEmpty &&
            _isValidFullAddress(fallbackAddress)) {
          _addressCache[key] = fallbackAddress;
          _isLoadingAddress[key] = false;
          return fallbackAddress;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error for coordinates ($latitude, $longitude): $e');

      // Retry mechanism
      if (currentRetry < maxRetries) {
        _retryCount[key] = currentRetry + 1;
        _isLoadingAddress[key] = false;

        // Wait before retry
        await Future.delayed(Duration(milliseconds: 1000 * (currentRetry + 1)));
        return _getFullAddressFromCoordinates(latitude, longitude);
      }
    }

    // Final fallback to coordinates
    _isLoadingAddress[key] = false;
    final coordinateFallback =
        'Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    _addressCache[key] = coordinateFallback;
    return coordinateFallback;
  }

  /// Builds complete Indonesian-style address as a single string
  String _buildCompleteIndonesianAddress(Placemark placemark) {
    List<String> addressParts = [];

    // 1. Priority: Landmark, building, or specific location name
    if (placemark.name != null &&
        placemark.name!.isNotEmpty &&
        !_isPlusCode(placemark.name!)) {
      String name = placemark.name!;
      // Filter out generic names that don't add value
      if (!_isGenericLocationName(name)) {
        addressParts.add(name);
      }
    }

    // 2. Street address with number
    String streetAddress = '';
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      streetAddress = placemark.street!;
    } else if (placemark.thoroughfare != null &&
        placemark.thoroughfare!.isNotEmpty) {
      streetAddress = placemark.thoroughfare!;
    }

    // Add building/house number if available
    if (placemark.subThoroughfare != null &&
        placemark.subThoroughfare!.isNotEmpty) {
      if (streetAddress.isNotEmpty) {
        streetAddress = '$streetAddress ${placemark.subThoroughfare!}';
      } else {
        streetAddress = placemark.subThoroughfare!;
      }
    }

    if (streetAddress.isNotEmpty && !_isGenericLocationName(streetAddress)) {
      addressParts.add(streetAddress);
    }

    // 3. Neighborhood/village (kelurahan/desa)
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      String neighborhood = placemark.subLocality!;
      if (!_isDuplicateOrGeneric(neighborhood, addressParts)) {
        addressParts.add(neighborhood);
      }
    }

    // 4. District (kecamatan) - with proper Indonesian formatting
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      String district = placemark.locality!;
      // Add "Kec." prefix if it's clearly a kecamatan and doesn't already have it
      if (_isIndonesianDistrict(district) &&
          !district.toLowerCase().contains('kec')) {
        district = 'Kec. $district';
      }
      if (!_isDuplicateOrGeneric(district, addressParts)) {
        addressParts.add(district);
      }
    }

    // 5. Sub-administrative area (kabupaten/kota)
    if (placemark.subAdministrativeArea != null &&
        placemark.subAdministrativeArea!.isNotEmpty) {
      String subAdmin = placemark.subAdministrativeArea!;
      if (!_isDuplicateOrGeneric(subAdmin, addressParts)) {
        addressParts.add(subAdmin);
      }
    }

    // 6. City/Regency (kota/kabupaten)
    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      String city = placemark.administrativeArea!;
      if (!_isDuplicateOrGeneric(city, addressParts)) {
        addressParts.add(city);
      }
    }

    // 7. Postal code
    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      addressParts.add(placemark.postalCode!);
    }

    return addressParts.join(', ');
  }

  /// Builds fallback complete address when primary method fails
  String _buildFallbackCompleteAddress(Placemark placemark) {
    List<String> parts = [];

    // Prioritize most specific available information
    if (placemark.name != null &&
        placemark.name!.isNotEmpty &&
        !_isPlusCode(placemark.name!)) {
      parts.add(placemark.name!);
    }

    if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
      parts.add(placemark.thoroughfare!);
    }

    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      parts.add(placemark.subLocality!);
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

    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
      parts.add(placemark.postalCode!);
    }

    return parts.join(', ');
  }

  /// Checks if location name is too generic to be useful
  bool _isGenericLocationName(String name) {
    final genericNames = [
      'unnamed road',
      'unnamed street',
      'jalan',
      'road',
      'street',
      'indonesia',
      'kalimantan',
      'java',
      'sumatra',
      'sulawesi',
      'building',
      'gedung',
      'komplek',
      'area',
    ];

    String lowerName = name.toLowerCase();
    return genericNames.any(
      (generic) => lowerName == generic || lowerName.startsWith('$generic '),
    );
  }

  /// Checks if this looks like an Indonesian district (kecamatan)
  bool _isIndonesianDistrict(String name) {
    // Simple heuristic: if it doesn't contain "kota" or "kab" it might be a kecamatan
    String lower = name.toLowerCase();
    return !lower.contains('kota') &&
        !lower.contains('kab') &&
        !lower.contains('city') &&
        !lower.contains('regency') &&
        name.length > 3; // Reasonable length for district name
  }

  /// Checks if a part is duplicate or too generic compared to existing parts
  bool _isDuplicateOrGeneric(String newPart, List<String> existingParts) {
    String lowerNew = newPart.toLowerCase();

    // Check for duplicates
    for (String existing in existingParts) {
      String lowerExisting = existing.toLowerCase();
      if (lowerNew == lowerExisting ||
          lowerNew.contains(lowerExisting) ||
          lowerExisting.contains(lowerNew)) {
        return true;
      }
    }

    return false;
  }

  /// Validates if the address is complete and user-friendly
  bool _isValidFullAddress(String address) {
    if (address.isEmpty) return false;

    // Check for plus codes or incomplete addresses
    final plusCodePattern = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}');
    if (plusCodePattern.hasMatch(address)) return false;

    // Check if address contains only coordinates
    final coordPattern = RegExp(r'^-?\d+\.?\d*,?\s*-?\d+\.?\d*$');
    if (coordPattern.hasMatch(address.replaceAll(RegExp(r'[^\d.,-]'), ''))) {
      return false;
    }

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

  /// Checks if a string is a plus code
  bool _isPlusCode(String text) {
    final plusCodePattern = RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}');
    return plusCodePattern.hasMatch(text);
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

  /// Returns a shorter version of the address for list display
  String _getShortDisplayAddress(String fullAddress) {
    if (fullAddress.startsWith('Location:')) {
      return fullAddress; // Keep coordinate fallbacks as-is
    }

    if (fullAddress.startsWith('Loading') ||
        fullAddress.startsWith('Unknown')) {
      return fullAddress; // Keep status messages as-is
    }

    // For full addresses, show only first 2-3 components
    final parts = fullAddress.split(', ');
    if (parts.length <= 3) {
      return fullAddress; // Already short enough
    }

    // Take first 2-3 meaningful parts
    final shortParts = parts.take(3).toList();
    return '${shortParts.join(', ')}...';
  }

  /// Shows a dialog with full location details in Google Maps format
  void _showLocationDetailsDialog(
    BuildContext context,
    String fullAddress,
    double latitude,
    double longitude,
    String timestamp,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text('Location Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  context,
                  Icons.place_rounded,
                  'Address',
                  fullAddress,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  Icons.my_location_rounded,
                  'Coordinates',
                  '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  isCoordinate: true,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  Icons.access_time_rounded,
                  'Timestamp',
                  timestamp,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a detail row for the dialog
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isCoordinate = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    fontFamily: isCoordinate ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primaryBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading driving history...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we fetch your location data',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error loading history',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // Trigger refresh - this would need to be passed from parent
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.historyEntries.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 56,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No driving history found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start driving to see your location history here.\nYour driving patterns will be recorded automatically.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Location updates every 15 minutes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryBlue,
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
                FutureBuilder<String>(
                  future: _getFullAddressFromCoordinates(
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
                      displayText = snapshot.data ?? 'Unknown location';

                      // Determine if this is a complete address or fallback
                      final isCompleteAddress =
                          _isValidFullAddress(displayText) &&
                          !displayText.startsWith('Location:');

                      if (isCompleteAddress) {
                        leadingIcon = Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        );
                      } else {
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
                        GestureDetector(
                          onTap: () {
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              _showLocationDetailsDialog(
                                context,
                                snapshot.data!,
                                entry.latitude,
                                entry.longitude,
                                _formatDateTime(entry.createdAt),
                              );
                            }
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: leadingIcon,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  _getShortDisplayAddress(displayText),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                    color: textColor,
                                    height: 1.4,
                                  ),
                                  maxLines: 2, // Shorter display for tap
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (snapshot.hasData && snapshot.data!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 1,
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
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
    );
  }
}

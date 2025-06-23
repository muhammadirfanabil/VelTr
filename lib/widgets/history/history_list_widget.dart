import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/history/history_service.dart';

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

        // Build a readable address
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

        // Fallback to administrative area if no specific location found
        if (address.isEmpty && placemark.administrativeArea != null) {
          address = placemark.administrativeArea!;
        }

        // Final fallback
        if (address.isEmpty) {
          address = 'Unknown location';
        }

        _addressCache[key] = address;
        return address;
      }
    } catch (e) {
      print('Error getting address for $latitude, $longitude: $e');
    }

    // Fallback to coordinates if geocoding fails
    final fallback =
        'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
    _addressCache[key] = fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Loading driving history...'),
          ],
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (widget.historyEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No driving history found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start driving to see your history here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.historyEntries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = widget.historyEntries[index];

        return Card(
          margin: EdgeInsets.zero,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                } else if (snapshot.hasError) {
                  displayText =
                      'In ${entry.latitude.toStringAsFixed(6)}, ${entry.longitude.toStringAsFixed(6)}';
                  leadingIcon = Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange[600],
                      shape: BoxShape.circle,
                    ),
                  );
                } else {
                  displayText = 'In ${snapshot.data ?? 'Unknown location'}';
                  leadingIcon = Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                    ),
                  );
                }

                return Row(
                  children: [
                    leadingIcon,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        displayText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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

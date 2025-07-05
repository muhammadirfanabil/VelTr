import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Add this import
import 'package:firebase_database/firebase_database.dart'; // Add Firebase import
import 'dart:async'; // Add for StreamSubscription
import '../../theme/app_colors.dart';

import '../widgets/tracker/info_grid.dart';
import '../widgets/tracker/locationdetail_dialog.dart';
import '../widgets/tracker/remote.dart';

class VehicleStatusPanel extends StatefulWidget {
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? lastUpdated;
  final String? waktuWita;
  final bool isVehicleOn;
  final VoidCallback toggleVehicleStatus;
  final int? satellites;
  final bool isLoading;
  final String deviceId; // Add deviceId parameter

  const VehicleStatusPanel({
    super.key,
    this.locationName,
    this.latitude,
    this.longitude,
    this.lastUpdated,
    this.waktuWita,
    required this.isVehicleOn,
    required this.toggleVehicleStatus,
    this.satellites,
    this.isLoading = false,
    required this.deviceId, // Add required deviceId
  });

  @override
  State<VehicleStatusPanel> createState() => _VehicleStatusPanelState();
}

class _VehicleStatusPanelState extends State<VehicleStatusPanel>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isActionInProgress = false;
  bool _wasOnlinePreviously = false;

  // Add Firebase real-time listening properties for GPS timestamp
  StreamSubscription<DatabaseEvent>? _gpsSubscription;
  DateTime? _lastGPSUpdateTime;
  bool _gpsDataReceived = false;

  // Separate relay status for the button
  bool _relayStatusFromFirebase = false;
  bool _relayDataReceived = false;
  StreamSubscription<DatabaseEvent>? _relaySubscription;

  /// Try to parse timestamp with multiple formats
  DateTime? _parseTimestamp(String timestampString) {
    final formats = [
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('dd-MM-yyyy HH:mm:ss'),
      DateFormat('yyyy-MM-ddTHH:mm:ss'),
      DateFormat('yyyy/MM/dd HH:mm:ss'),
      DateFormat('dd/MM/yyyy HH:mm:ss'),
      DateFormat('yyyy-MM-dd HH:mm:ss.SSS'),
      DateFormat('yyyy-MM-ddTHH:mm:ss.SSS'),
      DateFormat('yyyy-MM-ddTHH:mm:ss.SSSZ'),
      DateFormat('yyyy-MM-ddTHH:mm:ssZ'),
      DateFormat('EEE MMM dd HH:mm:ss yyyy'), // Day Month Date Time Year
      DateFormat('MMM dd, yyyy HH:mm:ss'), // Month Date, Year Time
    ];

    for (final format in formats) {
      try {
        final parsed = format.parse(timestampString);
        debugPrint(
          '✅ Successfully parsed with format ${format.pattern}: $timestampString -> $parsed',
        );
        return parsed;
      } catch (e) {
        // Continue to next format
      }
    }

    // Try ISO 8601 parsing as last resort
    try {
      final parsed = DateTime.parse(timestampString);
      debugPrint(
        '✅ Successfully parsed with DateTime.parse: $timestampString -> $parsed',
      );
      return parsed;
    } catch (e) {
      debugPrint(
        '❌ Failed to parse timestamp with any format: $timestampString',
      );
      return null;
    }
  }

  /// Convert WITA (UTC+8) timestamp to UTC - Only for fallback scenarios
  DateTime _witaToUtc(DateTime witaTime) {
    return witaTime.subtract(const Duration(hours: 8));
  }

  /// Parse UTC timestamp from tanggal + utc_time (preferred method)
  DateTime? _parseUtcTimestamp(String tanggal, String utcTime) {
    try {
      final timestampString = '$tanggal $utcTime';
      final parsed = _parseTimestamp(timestampString);
      if (parsed != null) {
        // Ensure it's treated as UTC
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
        );
      }
    } catch (e) {
      debugPrint('❌ Error parsing UTC timestamp: $e');
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
    _wasOnlinePreviously = isOnline;

    // Setup Firebase real-time listener for relay status
    _setupFirebaseListener();
  }

  void _setupFirebaseListener() {
    // Validate device ID before setting up listener
    if (widget.deviceId.isEmpty) {
      debugPrint('Warning: Device ID is empty, cannot setup Firebase listener');
      setState(() {
        _lastGPSUpdateTime = null;
        _gpsDataReceived = true;
        _relayStatusFromFirebase = false;
        _relayDataReceived = true;
        _rawFirebaseTimestamp = null;
      });
      return;
    }

    try {
      // Setup GPS listener for timestamp-based status
      final gpsRef = FirebaseDatabase.instance.ref(
        'devices/${widget.deviceId}/gps',
      );

      debugPrint('Setting up GPS listener for device: ${widget.deviceId}');

      _gpsSubscription = gpsRef.onValue.listen(
        (DatabaseEvent event) {
          if (mounted && event.snapshot.exists) {
            final gpsData = event.snapshot.value as Map<dynamic, dynamic>?;

            if (gpsData != null) {
              // Debug: Print all GPS data to understand structure
              debugPrint('🔍 Raw GPS Data: $gpsData');
              debugPrint('🔍 GPS Data Keys: ${gpsData.keys.toList()}');

              // Extract ALL possible timestamp fields for debugging
              final tanggal = gpsData['tanggal']?.toString();
              final utcTime = gpsData['utc_time']?.toString();
              final waktuWita = gpsData['waktu_wita']?.toString();
              final waktu = gpsData['waktu']?.toString();
              final timestamp = gpsData['timestamp']?.toString();

              // Check for actual field names from logs
              final date = gpsData['date']?.toString();
              final time = gpsData['time']?.toString();
              final wita_time = gpsData['wita_time']?.toString();
              final datetime = gpsData['datetime']?.toString();
              final created_at = gpsData['created_at']?.toString();
              final updated_at = gpsData['updated_at']?.toString();
              final lat =
                  gpsData['lat']?.toString() ?? gpsData['latitude']?.toString();
              final lng =
                  gpsData['lng']?.toString() ??
                  gpsData['longitude']?.toString();

              debugPrint('🕐 All timestamp fields found:');
              debugPrint('  - tanggal: $tanggal');
              debugPrint('  - utc_time: $utcTime');
              debugPrint('  - waktu_wita: $waktuWita');
              debugPrint('  - waktu: $waktu');
              debugPrint('  - timestamp: $timestamp');
              debugPrint('  - date: $date');
              debugPrint('  - time: $time');
              debugPrint('  - wita_time: $wita_time');
              debugPrint('  - datetime: $datetime');
              debugPrint('  - created_at: $created_at');
              debugPrint('  - updated_at: $updated_at');
              debugPrint('  - lat: $lat, lng: $lng');

              DateTime? lastUpdateTime;

              // Priority 1: Use date + utc_time (actual Firebase structure)
              if (date != null && utcTime != null) {
                lastUpdateTime = _parseUtcTimestamp(date, utcTime);
                if (lastUpdateTime != null) {
                  debugPrint(
                    '✅ Using date + utc_time (UTC): $date $utcTime -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 2: Use tanggal + utc_time (fallback)
              else if (tanggal != null && utcTime != null) {
                lastUpdateTime = _parseUtcTimestamp(tanggal, utcTime);
                if (lastUpdateTime != null) {
                  debugPrint(
                    '✅ Using tanggal + utc_time (UTC): $tanggal $utcTime -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 3: Use date + time combination
              else if (date != null && time != null) {
                lastUpdateTime = _parseUtcTimestamp(date, time);
                if (lastUpdateTime != null) {
                  debugPrint(
                    '✅ Using date + time (UTC): $date $time -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 3: Use datetime field directly
              else if (datetime != null) {
                final parsedTime = _parseTimestamp(datetime);
                if (parsedTime != null) {
                  lastUpdateTime = parsedTime.toUtc();
                  debugPrint(
                    '✅ Using datetime field (UTC): $datetime -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 4: Use created_at or updated_at
              else if (created_at != null) {
                final parsedTime = _parseTimestamp(created_at);
                if (parsedTime != null) {
                  lastUpdateTime = parsedTime.toUtc();
                  debugPrint(
                    '✅ Using created_at (UTC): $created_at -> $lastUpdateTime UTC',
                  );
                }
              } else if (updated_at != null) {
                final parsedTime = _parseTimestamp(updated_at);
                if (parsedTime != null) {
                  lastUpdateTime = parsedTime.toUtc();
                  debugPrint(
                    '✅ Using updated_at (UTC): $updated_at -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 5: Fallback to tanggal + waktu_wita (convert to UTC)
              else if (tanggal != null && waktuWita != null) {
                final timestampString = '$tanggal $waktuWita';
                final parsedTime = _parseTimestamp(timestampString);
                if (parsedTime != null) {
                  // waktu_wita is WITA (UTC+8), convert to UTC
                  lastUpdateTime = _witaToUtc(parsedTime);
                  debugPrint(
                    '✅ Fallback tanggal + waktu_wita (converted to UTC): $timestampString -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 6: Fallback to tanggal + waktu
              else if (tanggal != null && waktu != null) {
                final timestampString = '$tanggal $waktu';
                final parsedTime = _parseTimestamp(timestampString);
                if (parsedTime != null) {
                  // Assume waktu is also WITA, convert to UTC
                  lastUpdateTime = _witaToUtc(parsedTime);
                  debugPrint(
                    '✅ Fallback tanggal + waktu (converted to UTC): $timestampString -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 7: Direct timestamp fallback
              else if (timestamp != null) {
                final parsedTime = _parseTimestamp(timestamp);
                if (parsedTime != null) {
                  // Assume timestamp is already UTC
                  lastUpdateTime = parsedTime.toUtc();
                  debugPrint(
                    '✅ Fallback direct timestamp (UTC): $timestamp -> $lastUpdateTime UTC',
                  );
                }
              }
              // Priority 8: If we have lat/lng, use current time as last update (device is sending data)
              else if (lat != null && lng != null) {
                // If we have coordinate data, the device is active, use current time
                lastUpdateTime = DateTime.now().toUtc();
                debugPrint(
                  '✅ Using current time (device has coordinates): lat=$lat, lng=$lng -> $lastUpdateTime UTC',
                );
                // Set a meaningful display message
                _rawFirebaseTimestamp = 'Device Active (GPS data received)';
              }
              // Priority 9: If we have any GPS data at all but no timestamp, show that device is active
              else if (gpsData.isNotEmpty) {
                lastUpdateTime = DateTime.now().toUtc();
                debugPrint(
                  '✅ Using current time (GPS node has data): keys=${gpsData.keys.toList()} -> $lastUpdateTime UTC',
                );
                // Set a meaningful display message
                _rawFirebaseTimestamp = 'Device Active (data received)';
              }

              // If all parsing fails, we don't have valid timestamp data
              if (lastUpdateTime == null) {
                debugPrint(
                  '⚠️ Could not parse any timestamp, no valid GPS data available',
                );
                // Don't set _lastGPSUpdateTime, leave it as null
                setState(() {
                  _lastGPSUpdateTime = null;
                  _gpsDataReceived = true;
                  _rawFirebaseTimestamp = null;
                });
                return;
              }

              setState(() {
                _lastGPSUpdateTime = lastUpdateTime;
                _gpsDataReceived = true;

                // Convert UTC timestamp to user's local timezone for display
                if (lastUpdateTime != null) {
                  final localTime = lastUpdateTime.toLocal();
                  final now = DateTime.now().toLocal();
                  
                  // Format timestamp based on how recent it is
                  if (localTime.year == now.year &&
                      localTime.month == now.month &&
                      localTime.day == now.day) {
                    // Same day - show only time (24-hour format)
                    _rawFirebaseTimestamp = 
                        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
                  } else {
                    // Different day - show date and time in user's local timezone
                    final formatter = DateFormat('MMM dd, HH:mm');
                    _rawFirebaseTimestamp = formatter.format(localTime);
                  }
                  
                  debugPrint('🌐 Converted UTC to local time for display: $lastUpdateTime UTC -> $localTime Local -> $_rawFirebaseTimestamp');
                } else if (date != null && utcTime != null) {
                  // Fallback: display raw server data if parsing failed
                  _rawFirebaseTimestamp = '$date $utcTime UTC';
                } else if (tanggal != null && utcTime != null) {
                  _rawFirebaseTimestamp = '$tanggal $utcTime UTC';
                } else {
                  _rawFirebaseTimestamp = 'Device Active';
                }
              });

              debugPrint('📍 GPS timestamp updated: $_lastGPSUpdateTime');
            } else {
              debugPrint('❌ GPS data is null');
              setState(() {
                _lastGPSUpdateTime = null;
                _gpsDataReceived = true;
                _rawFirebaseTimestamp = null;
              });
            }
          } else if (mounted) {
            setState(() {
              _lastGPSUpdateTime = null;
              _gpsDataReceived = true;
              _rawFirebaseTimestamp = null;
            });
            debugPrint('❌ GPS data not found for device: ${widget.deviceId}');
          }
        },
        onError: (error) {
          debugPrint(
            '❌ GPS listener error for device ${widget.deviceId}: $error',
          );
          if (mounted) {
            setState(() {
              _lastGPSUpdateTime = null;
              _gpsDataReceived = true;
              _rawFirebaseTimestamp = null;
            });
          }
        },
      );

      // Setup relay listener for vehicle control (separate from status)
      final relayRef = FirebaseDatabase.instance.ref(
        'devices/${widget.deviceId}/relay',
      );

      debugPrint('Setting up relay listener for device: ${widget.deviceId}');

      _relaySubscription = relayRef.onValue.listen(
        (DatabaseEvent event) {
          if (mounted && event.snapshot.exists) {
            final relayValue = event.snapshot.value;
            final newRelayStatus = relayValue == true;

            setState(() {
              _relayStatusFromFirebase = newRelayStatus;
              _relayDataReceived = true;
            });

            debugPrint(
              'Firebase relay status updated: $relayValue (Relay: $newRelayStatus)',
            );
          } else if (mounted) {
            setState(() {
              _relayStatusFromFirebase = false;
              _relayDataReceived = true;
            });
            debugPrint(
              'Firebase relay data not found for device: ${widget.deviceId}',
            );
          }
        },
        onError: (error) {
          debugPrint(
            'Firebase relay listener error for device ${widget.deviceId}: $error',
          );
          if (mounted) {
            setState(() {
              _relayStatusFromFirebase = false;
              _relayDataReceived = true;
            });
          }
        },
      );
    } catch (e) {
      debugPrint(
        'Error setting up Firebase listeners for device ${widget.deviceId}: $e',
      );
      if (mounted) {
        setState(() {
          _lastGPSUpdateTime = null;
          _gpsDataReceived = true;
          _relayStatusFromFirebase = false;
          _relayDataReceived = true;
          _rawFirebaseTimestamp = null;
        });
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(VehicleStatusPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasOnline = _wasOnlinePreviously;
    final isCurrentlyOnline = isOnline;

    if (wasOnline != isCurrentlyOnline) {
      _wasOnlinePreviously = isCurrentlyOnline;
    }
  }

  @override
  void dispose() {
    // Clean up the Firebase listeners
    _gpsSubscription?.cancel();
    _relaySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // --- Logic Getters ---

  bool get hasValidCoordinates {
    return widget.latitude != null &&
        widget.longitude != null &&
        widget.latitude!.abs() <= 90 &&
        widget.longitude!.abs() <= 180 &&
        widget.latitude != 0.0 &&
        widget.longitude != 0.0;
  }

  String get coordinatesText {
    if (!hasValidCoordinates) return 'Coordinates not available';
    return '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}';
  }

  /// Get the timestamp display adjusted to user's local timezone
  String get rawTimestampDisplay {
    // This shows the timestamp in user's local timezone for better UX
    return _rawFirebaseTimestamp ?? 'No recent data';
  }

  // Store the timestamp converted to user's local timezone for display
  String? _rawFirebaseTimestamp;

  String get lastActiveText {
    // Priority 1: Use local timezone display from Firebase timestamp
    if (_gpsDataReceived && _lastGPSUpdateTime != null) {
      final lastUpdate = _lastGPSUpdateTime!; // Already in UTC
      
      // Convert UTC to user's local time for display
      final localTime = lastUpdate.toLocal();
      final now = DateTime.now().toLocal();
      
      debugPrint('🌐 Converting GPS time for display: UTC=$lastUpdate -> Local=$localTime');
      
      // Format based on how recent it is
      if (localTime.year == now.year &&
          localTime.month == now.month &&
          localTime.day == now.day) {
        // Same day - show only time (24-hour format)
        return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
      } else {
        // Different day - show date and time in user's local timezone
        final formatter = DateFormat('MMM dd, HH:mm');
        return formatter.format(localTime);
      }
    }

    // Priority 2: Use pre-computed raw Firebase timestamp (already in local time)
    if (_gpsDataReceived && _rawFirebaseTimestamp != null) {
      debugPrint('✅ Using pre-computed local timestamp: $_rawFirebaseTimestamp');
      return _rawFirebaseTimestamp!;
    }

    // Priority 3: Fallback to widget lastUpdated (with timezone conversion)
    if (widget.lastUpdated?.isNotEmpty == true &&
        widget.lastUpdated != 'Invalid timestamp' &&
        widget.lastUpdated != 'No GPS data' &&
        widget.lastUpdated != '-') {
      try {
        final updatedTime = _parseTimestamp(widget.lastUpdated!);
        if (updatedTime != null) {
          // Assume fallback timestamp is WITA, convert to UTC then to local for display
          final updatedTimeUtc = _witaToUtc(updatedTime);
          final localTime = updatedTimeUtc.toLocal();
          final now = DateTime.now().toLocal();

          debugPrint(
            '🌐 Fallback conversion: WITA=$updatedTime -> UTC=$updatedTimeUtc -> Local=$localTime',
          );

          // Format based on how recent it is
          if (localTime.year == now.year &&
              localTime.month == now.month &&
              localTime.day == now.day) {
            // Same day - show only time (24-hour format)
            return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
          } else {
            // Different day - show date and time in user's local timezone
            final formatter = DateFormat('MMM dd, HH:mm');
            return formatter.format(localTime);
          }
        }
      } catch (e) {
        debugPrint('❌ Error parsing fallback timestamp: $e');
      }
    }

    // Priority 4: Default fallback
    return 'No recent data';
  }

  bool get isOnline {
    // Use GPS timestamp-based logic for online status (all UTC)
    if (_gpsDataReceived && _lastGPSUpdateTime != null) {
      // Get current UTC time
      final now = DateTime.now().toUtc();
      final lastUpdate =
          _lastGPSUpdateTime!; // Already in UTC from GPS listener

      // Calculate difference in minutes
      final differenceInMinutes = now.difference(lastUpdate).inMinutes;

      // Device is online if last update was less than 2 minutes ago
      final isDeviceOnline = differenceInMinutes < 2;

      debugPrint(
        'GPS Timestamp Status Check (UTC Priority): '
        'Now: $now UTC, '
        'Last Update: $lastUpdate UTC, '
        'Diff: ${differenceInMinutes}min, '
        'Online: $isDeviceOnline',
      );

      return isDeviceOnline;
    }

    // Fallback to timestamp string logic if GPS data not available (convert to UTC)
    if (widget.lastUpdated == null ||
        widget.lastUpdated!.isEmpty ||
        widget.lastUpdated == '-') {
      return false;
    }

    try {
      final updatedTime = _parseTimestamp(widget.lastUpdated!);

      if (updatedTime != null) {
        // Assume fallback timestamp is WITA, convert to UTC
        final updatedTimeUtc = _witaToUtc(updatedTime);
        final now = DateTime.now().toUtc();
        final differenceInMinutes = now.difference(updatedTimeUtc).inMinutes;

        // Device is online if last update was less than 2 minutes ago
        final isDeviceOnline = differenceInMinutes < 2;

        debugPrint(
          'Fallback Timestamp Status Check (UTC): '
          'Now: $now UTC, '
          'Updated: $updatedTimeUtc UTC (converted from WITA), '
          'Diff: ${differenceInMinutes}min, '
          'Online: $isDeviceOnline',
        );

        return isDeviceOnline;
      } else {
        debugPrint('Failed to parse fallback timestamp: ${widget.lastUpdated}');
        return false;
      }
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      debugPrint('Timestamp value: ${widget.lastUpdated}');
      return false;
    }
  }

  String get connectionQuality {
    if (!isOnline) return 'No Signal';

    final satellites = widget.satellites ?? 0;
    if (satellites >= 8) return 'Excellent';
    if (satellites >= 6) return 'Good';
    if (satellites >= 4) return 'Fair';
    if (satellites >= 2) return 'Poor';
    return 'No Signal';
  }

  Color get connectionQualityColor {
    switch (connectionQuality) {
      case 'Excellent':
        return Colors.teal.shade800;
      case 'Good':
        return AppColors.success.withValues(alpha: 0.8);
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return AppColors.error;
      case 'No Signal':
      default:
        return Colors.black;
    }
  }

  /// Get the actual vehicle/relay status from Firebase
  /// Falls back to widget value if Firebase data is not available
  bool _getActualVehicleStatus() {
    // Use Firebase relay data if available, otherwise fall back to widget data
    if (_relayDataReceived) {
      return _relayStatusFromFirebase;
    }

    // Fallback to widget value if Firebase data not yet received
    return widget.isVehicleOn;
  }

  // --- UI Actions ---
  Future<void> _copyLocation() async {
    if (!hasValidCoordinates) {
      _showSnackBar('No valid coordinates to copy', isError: true);
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: coordinatesText));
      _showSnackBar('Coordinates copied to clipboard');
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to copy coordinates: $e');
      _showSnackBar('Failed to copy coordinates', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  Future<void> _handleVehicleToggle() async {
    if (_isActionInProgress || widget.isLoading) return;

    setState(() {
      _isActionInProgress = true;
    });

    try {
      HapticFeedback.heavyImpact();

      // Store the expected new state
      final expectedNewState = !_getActualVehicleStatus();
      debugPrint('Toggle initiated - Expected new state: $expectedNewState');

      // Call the parent toggle function
      widget.toggleVehicleStatus();

      // Wait for Firebase to update (with timeout)
      int attempts = 0;
      const maxAttempts = 10; // 5 seconds max wait
      while (attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (_relayDataReceived &&
            _relayStatusFromFirebase == expectedNewState) {
          debugPrint(
            'Firebase confirmed toggle - New state: $_relayStatusFromFirebase',
          );
          break;
        }

        attempts++;
        debugPrint(
          'Waiting for Firebase confirmation... Attempt $attempts/$maxAttempts',
        );
      }

      if (attempts >= maxAttempts) {
        debugPrint('Toggle timeout - Firebase may not have updated');
        _showSnackBar('Device toggle may not have completed', isError: true);
      } else {
        _showSnackBar(
          expectedNewState ? 'Device turned on' : 'Device turned off',
          isError: false,
        );
      }
    } catch (e) {
      debugPrint('Error toggling vehicle status: $e');
      _showSnackBar('Failed to toggle vehicle status', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  void _showLocationDetails() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => LocationDetailsDialog(
            locationName: widget.locationName,
            latitude: widget.latitude,
            longitude: widget.longitude,
            lastUpdated: lastActiveText,
            satellites: widget.satellites,
            connectionQuality: connectionQuality,
            connectionQualityColor: connectionQualityColor,
            onCopyCoordinates: hasValidCoordinates ? _copyLocation : null,
          ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _buildPanel(theme),
          ),
        );
      },
    );
  }

  Widget _buildPanel(ThemeData theme) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 14),
              BuildInfoGrid(
                theme: theme,
                lastUpdate: lastActiveText,
                connectionQuality:
                    connectionQuality, // This is now fixed with a dynamic value
                connectionQualityColor:
                    connectionQualityColor, // so is this one
                hasValidCoordinates:
                    widget.latitude != null && widget.longitude != null,
                coordinatesText: coordinatesText,
                onCopyLocation: _copyLocation,
              ),

              const SizedBox(height: 16),
              BuildActionButton(
                isVehicleOn: _getActualVehicleStatus(),
                isDisabled: _isActionInProgress || widget.isLoading,
                onPressed: _handleVehicleToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showLocationDetails,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLocationDisplayText(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap for details',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildStatusBadge(theme),
      ],
    );
  }

  String _getLocationDisplayText() {
    if (widget.isLoading) return 'Loading location...';
    if (widget.locationName?.isNotEmpty == true) return widget.locationName!;
    return 'Location unavailable';
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final online = isOnline;

    // Debug: Print current status source (prioritizing UTC timestamp)
    debugPrint(
      '🔴 Status Badge - GPS received: $_gpsDataReceived, '
      'GPS timestamp (UTC): $_lastGPSUpdateTime, '
      'Final online status: $online',
    );

    return Container(
      width: 72, // Fixed width to ensure consistent size
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color:
            online
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.error.withValues(alpha: 0.10),
        border: Border.all(
          color:
              online
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.error.withValues(alpha: 0.25),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Center the content
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: online ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
              boxShadow:
                  online
                      ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            // Use Flexible to prevent overflow
            child: Text(
              online ? 'Online' : 'Offline',
              style: theme.textTheme.bodySmall?.copyWith(
                color: online ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center, // Center align the text
              overflow: TextOverflow.ellipsis, // Handle potential overflow
            ),
          ),
        ],
      ),
    );
  }
}

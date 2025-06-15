import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapControllerHelper {
  /// Safely moves the map to a position with retry logic
  static void safeMoveMap(
    MapController controller,
    LatLng position,
    double zoom,
  ) {
    try {
      controller.move(position, zoom);
    } catch (e) {
      debugPrint('MapController move error: $e');
      retryMapMove(controller, position, zoom, 1);
    }
  }

  /// Retries moving the map with progressive delays
  static void retryMapMove(
    MapController controller,
    LatLng position,
    double zoom,
    int attempt,
  ) {
    final delays = [200, 500, 1000]; // Progressive delays in milliseconds

    if (attempt > delays.length) {
      debugPrint('MapController move failed after ${delays.length} attempts');
      return;
    }

    Future.delayed(Duration(milliseconds: delays[attempt - 1]), () {
      try {
        controller.move(position, zoom);
        debugPrint('MapController move succeeded on attempt $attempt');
      } catch (retryError) {
        debugPrint('MapController move attempt $attempt failed: $retryError');
        retryMapMove(controller, position, zoom, attempt + 1);
      }
    });
  }
}

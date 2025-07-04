import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/history/history_service.dart';

class HistoryMapWidget extends StatelessWidget {
  final List<HistoryEntry> historyEntries;
  final List<LatLng> polylinePoints;
  final MapController mapController;
  final bool isLoading;
  final String? error;

  const HistoryMapWidget({
    super.key,
    required this.historyEntries,
    required this.polylinePoints,
    required this.mapController,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildMapContent(),
      ),
    );
  }

  Widget _buildMapContent() {
    if (isLoading) {
      return Container(
        height: 400,
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading driving history...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        height: 400,
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
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
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (historyEntries.isEmpty) {
      return Container(
        height: 400,
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Driving History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This vehicle has no recorded trips in the selected time period.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter:
            polylinePoints.isNotEmpty
                ? polylinePoints.first
                : const LatLng(0, 0),
        initialZoom: 13.0,
        minZoom: 3.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gpsapp.flutter',
        ),
        if (polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polylinePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        if (polylinePoints.isNotEmpty) ...[
          // Start marker
          MarkerLayer(
            markers: [
              Marker(
                point: polylinePoints.first,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          // End marker
          MarkerLayer(
            markers: [
              Marker(
                point: polylinePoints.last,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

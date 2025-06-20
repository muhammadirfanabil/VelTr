import 'package:flutter/material.dart';

class GeofenceActionButtons extends StatelessWidget {
  final bool showPolygon;
  final bool isSaving;
  final int pointCount;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onContinue;
  final VoidCallback onSave;

  const GeofenceActionButtons({
    super.key,
    required this.showPolygon,
    required this.isSaving,
    required this.pointCount,
    required this.onUndo,
    required this.onReset,
    required this.onContinue,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showPolygon && pointCount > 0) ...[
            _buildUndoButton(),
            const SizedBox(height: 12),
          ],
          if (showPolygon && pointCount > 0) ...[
            _buildResetButton(),
            const SizedBox(height: 12),
          ],
          _buildMainActionButton(),
        ],
      ),
    );
  }

  Widget _buildUndoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onUndo,
        icon: const Icon(Icons.undo),
        label: const Text('Undo Last Point'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.clear_all),
        label: const Text('Reset All Points'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    if (showPolygon && pointCount >= 3) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : onSave,
          icon:
              isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                  : const Icon(Icons.save),
          label: Text(isSaving ? 'Saving...' : 'Save Geofence'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          pointCount < 3
              ? 'Add ${3 - pointCount} more point${3 - pointCount == 1 ? '' : 's'}'
              : 'Continue',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

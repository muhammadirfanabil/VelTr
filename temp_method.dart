  /// Build the floating centering buttons (bottom-right corner)
  Widget _buildCenteringButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Center to User Location button
        Tooltip(
          message: 'Center on your location',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _isLoadingUserLocation ? null : _centerOnUser,
                child: Center(
                  child: _isLoadingUserLocation
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        )
                      : Icon(
                          Icons.my_location,
                          color: _userLocation != null ? Colors.blue : Colors.grey,
                          size: 28,
                          semanticLabel: 'Center on your location',
                        ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Center to Device Location button
        Tooltip(
          message: 'Center on device location',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: vehicleLocation != null ? _centerOnDevice : null,
                child: Center(
                  child: Icon(
                    Icons.gps_fixed,
                    color: vehicleLocation != null ? Colors.orange : Colors.grey,
                    size: 28,
                    semanticLabel: 'Center on device location',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

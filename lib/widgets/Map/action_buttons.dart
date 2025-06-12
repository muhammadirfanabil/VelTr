import 'package:flutter/material.dart';
import '../Common/user_menu.dart';

class MapActionButtons extends StatelessWidget {
  final bool isLoading;
  final bool hasGPSData;
  final VoidCallback onRefresh;
  final VoidCallback onShowGPSInfo;
  final Function(String) onMenuItemSelected;

  const MapActionButtons({
    Key? key,
    required this.isLoading,
    required this.hasGPSData,
    required this.onRefresh,
    required this.onShowGPSInfo,
    required this.onMenuItemSelected,
  }) : super(key: key);

  Widget _buildFloatingButton({
    required Widget child,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(icon: child, onPressed: onPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildFloatingButton(
          child:
              isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          onPressed: isLoading ? null : onRefresh,
        ),
        const SizedBox(width: 8),
        if (!hasGPSData)
          _buildFloatingButton(
            child: const Icon(Icons.info_outline),
            onPressed: onShowGPSInfo,
          ),
        const SizedBox(width: 8),
        UserMenu(onMenuItemSelected: onMenuItemSelected),
      ],
    );
  }
}

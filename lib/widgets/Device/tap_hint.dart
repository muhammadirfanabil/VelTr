import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DeviceTapHint extends StatelessWidget {
  const DeviceTapHint({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.infoLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 14, color: AppColors.infoText),
          const SizedBox(width: 4),
          Text(
            'Tap to view geofences',
            style: TextStyle(
              color: AppColors.infoText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

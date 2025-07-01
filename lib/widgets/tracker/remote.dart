import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BuildActionButton extends StatelessWidget {
  final bool isVehicleOn;
  final bool isDisabled;
  final VoidCallback onPressed;

  const BuildActionButton({
    required this.isVehicleOn,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isDisabled ? null : onPressed,
        icon:
            isDisabled
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Icon(
                  isVehicleOn
                      ? Icons.power_settings_new_rounded
                      : Icons.power_settings_new_outlined,
                  size: 20,
                ),
        label: Text(
          isVehicleOn ? 'Turn Off Device' : 'Turn On Device',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              isDisabled
                  ? AppColors.textTertiary.withValues(alpha: 0.3)
                  : (isVehicleOn ? AppColors.success : AppColors.error),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

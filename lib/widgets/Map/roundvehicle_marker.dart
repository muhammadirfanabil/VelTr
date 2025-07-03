import 'package:flutter/material.dart';

class RoundVehicleMarker extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final bool
  isOn; // Added `isOn` parameter to determine the status of the vehicle

  const RoundVehicleMarker({
    Key? key,
    required this.pulseAnimation,
    required this.isOn, // Accept `isOn` as a parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 24.0,
                height: 24.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      'assets/icons/motor.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.motorcycle,
                            color: Colors.blue,
                            size: 12,
                          ),
                    ),
                  ),
                ),
              ),
              // Indicator for online/offline (isOn)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn ? Colors.green : Colors.red,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

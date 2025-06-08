import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VehicleMarkerIcon extends StatelessWidget {
  final bool isOn; // true = nyala, false = mati

  const VehicleMarkerIcon({super.key, required this.isOn});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SvgPicture.asset(
            'assets/icons/motor.svg',
            width: 20,
            height: 20,
          ),
          // child: Icon(Icons.motorcycle, size: 30, color: Colors.black),
        ),
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
    );
  }
}

import 'package:flutter/material.dart';

class StickyFooter extends StatelessWidget {
  const StickyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Location Pin Icon
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    // TODO: Add your location pin action
                  },
                  icon: Icon(Icons.location_pin, color: Colors.black),
                  tooltip: 'Location Pin',
                ),
              ],
            ),

            // Vehicle
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/vehicle');
                  },
                  icon: Icon(Icons.two_wheeler, color: Colors.black),
                  tooltip: 'Two Wheeler',
                ),
              ],
            ),

            // Notifications
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                  icon: Icon(Icons.notifications, color: Colors.black),
                  tooltip: 'Notifications',
                ),
              ],
            ),

            // Profile
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/vehicle');
                  },
                  icon: Icon(Icons.person, color: Colors.black),
                  tooltip: 'Profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

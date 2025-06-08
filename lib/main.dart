import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gps_app/screens/Auth/RegisterOne.dart';
import 'package:gps_app/screens/Auth/GoogleSignupScreen.dart';
import 'package:gps_app/screens/GeoFence/device_geofence.dart';
// import 'package:gps_app/screens/GeoFence/index.dart';
import 'package:gps_app/screens/Index.dart';
import 'package:gps_app/screens/Users/Profile.dart';
import 'package:gps_app/screens/device/index.dart';
import 'package:gps_app/screens/users/edit_profile.dart';
import 'package:gps_app/screens/vehicle/manage.dart';
import 'package:gps_app/screens/vehicle/history.dart';

import 'firebase_options.dart';
import 'screens/Auth/login.dart';
import 'screens/Vehicle/index.dart';
import 'screens/Maps/mapView.dart';
import 'screens/GeoFence/index.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Pengguna',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'PlusJakarta'),
      debugShowCheckedModeBanner: false,
      routes: {
        // Authentications
        '/registerone': (context) => const RegisterOne(),
        '/login': (context) => const LoginScreen(),

        // '/map': (context) => const IndexScreen(),

        // Home Page
        '/home': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final deviceId = args?['deviceId'] as String? ?? 'B0A7322B2EC4';
          return GPSMapScreen(deviceId: deviceId);
        },

        // Vehicle
        '/vehicle': (context) => const VehicleIndexScreen(),
        '/manage-vehicle': (context) => const ManageVehicle(),
        '/geofence': (context) => const DeviceManagerScreen(),
        '/drive-history': (context) => const DrivingHistory(),
        // '/geofence': (context) => const GeofenceListScreen(),
        // '/geofence': (context) {
        //   // Extract deviceId from route arguments
        //   final args =
        //       ModalRoute.of(context)?.settings.arguments
        //           as Map<String, dynamic>?;
        //   final deviceId = args?['deviceId'] as String? ?? 'default_device_id';
        //   return DeviceListScreen(deviceId: deviceId);
        // },
        '/set-range': (context) {
          // Extract deviceId from route arguments
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final deviceId = args?['deviceId'] as String? ?? 'default_device_id';
          return DeviceListScreen(deviceId: deviceId);
        },
        '/notifications': (context) => const NotificationsScreen(),
        '/profile': (context) => const ProfilePage(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/google-signup': (context) {
          // We'll pass the parameters when navigating to this route
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return GoogleSignupScreen(
            email: args['email']!,
            displayName: args['displayName']!,
          );
        },
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return const LoginScreen();
          }

          return const GPSMapScreen(deviceId: 'default_device_id');

          // return const GPSMapScreen(deviceId: 'B0A7322B2EC4');
        },
      ),
    );
  }
}

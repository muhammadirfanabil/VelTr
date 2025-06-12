import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gps_app/screens/Auth/RegisterOne.dart';
import 'package:gps_app/screens/Auth/GoogleSignupScreen.dart';
import 'package:gps_app/screens/GeoFence/device_geofence.dart';
// import 'package:gps_app/screens/Index.dart';
// import 'package:gps_app/screens/GeoFence/index.dart';
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
import 'services/notifications/fcm_service.dart';
import 'services/device/deviceService.dart';

import 'models/Device/device.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final fcmService = FCMService();
  await fcmService.initFCM();

  runApp(const MyApp());
}

/// Device Router Widget - Handles dynamic device selection for GPS routing
class DeviceRouterScreen extends StatefulWidget {
  const DeviceRouterScreen({Key? key}) : super(key: key);

  @override
  _DeviceRouterScreenState createState() => _DeviceRouterScreenState();
}

class _DeviceRouterScreenState extends State<DeviceRouterScreen> {
  final DeviceService _deviceService = DeviceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Device>>(
        stream: _deviceService.getDevicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your devices...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error.toString());
          }
          final devices =
              snapshot.data ??
              []; // Always navigate to map view regardless of device availability
          // The map will handle no-device scenarios internally
          final primaryDevice = _getPrimaryDevice(devices);

          // Use primary device if available, otherwise use placeholder
          final deviceId = primaryDevice?.name ?? 'no_device_placeholder';

          debugPrint('🚀 [DEVICE_ROUTER] Device selection logic:');
          debugPrint(
            '🚀 [DEVICE_ROUTER] Total devices found: ${devices.length}',
          );
          debugPrint(
            '🚀 [DEVICE_ROUTER] Primary device selected: ${primaryDevice?.name ?? "none"}',
          );
          debugPrint(
            '🚀 [DEVICE_ROUTER] Final deviceId for GPS map: $deviceId',
          );
          debugPrint('🚀 [DEVICE_ROUTER] Navigating to GPSMapScreen...');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => GPSMapScreen(deviceId: deviceId),
              ),
            );
          });

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing GPS app...'),
              ],
            ),
          );
        },
      ),
    );
  }

  Device? _getPrimaryDevice(List<Device> devices) {
    debugPrint(
      '🎯 [DEVICE_SELECTION] Selecting primary device from ${devices.length} devices',
    );

    // Priority: Active devices with valid GPS coordinates
    final activeWithGPS = devices.where((d) => d.isActive && d.hasValidGPS);
    debugPrint(
      '🎯 [DEVICE_SELECTION] Active devices with GPS: ${activeWithGPS.length}',
    );

    if (activeWithGPS.isNotEmpty) {
      final selected = activeWithGPS.first;
      debugPrint(
        '🎯 [DEVICE_SELECTION] Selected device with GPS: ${selected.name}',
      );
      return selected;
    }

    // Fallback: Any active device
    final activeDevices = devices.where((d) => d.isActive);
    debugPrint(
      '🎯 [DEVICE_SELECTION] Active devices (any): ${activeDevices.length}',
    );

    if (activeDevices.isNotEmpty) {
      final selected = activeDevices.first;
      debugPrint(
        '🎯 [DEVICE_SELECTION] Selected active device: ${selected.name}',
      );
      return selected;
    }

    // Last resort: Any device
    final anyDevice = devices.isNotEmpty ? devices.first : null;
    debugPrint(
      '🎯 [DEVICE_SELECTION] Last resort device: ${anyDevice?.name ?? "none"}',
    );
    return anyDevice;
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Error'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade600),
              const SizedBox(height: 24),
              Text(
                'Unable to load devices',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

        // Home Page - Now uses dynamic device routing
        '/home': (context) => const DeviceRouterScreen(),

        // Vehicle
        '/vehicle': (context) => const VehicleIndexScreen(),
        '/manage-vehicle': (context) => const ManageVehicle(),
        '/geofence': (context) {
          // Extract deviceId from route arguments
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final deviceId = args?['deviceId'] as String?;
          return deviceId != null
              ? GeofenceListScreen(deviceId: deviceId)
              : const DeviceRouterScreen();
        },
        '/device': (context) => const DeviceManagerScreen(),
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
          final deviceId = args?['deviceId'] as String?;
          return deviceId != null
              ? DeviceListScreen(deviceId: deviceId)
              : const DeviceRouterScreen();
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

          // Use DeviceRouterScreen instead of hardcoded device
          return const DeviceRouterScreen();
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'themes/app_theme.dart';

// Screen imports
import 'screens/Auth/login.dart';
import 'screens/Auth/RegisterOne.dart';
import 'screens/Auth/GoogleSignupScreen.dart';
import 'screens/Users/Profile.dart';
import 'screens/users/edit_profile.dart';
import 'screens/Vehicle/index.dart';
import 'screens/vehicle/manage.dart';
import 'screens/vehicle/history.dart';
import 'screens/Maps/mapView.dart';
import 'screens/GeoFence/index.dart';
import 'screens/GeoFence/device_geofence.dart';
import 'screens/device/index.dart';
import 'screens/notifications/notifications_screen.dart';

// Widget Imports
import 'widgets/Common/loading_screen.dart';
import 'widgets/Common/error_card.dart';

// Service imports
import 'services/notifications/fcm_service.dart';
import 'services/device/deviceService.dart';
import 'services/Auth/AuthService.dart';

// Model imports
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
            return const LoadingScreen(message: 'Loading your devices...');
          }

          if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error.toString());
          }

          final devices = snapshot.data ?? [];

          if (devices.isEmpty) {
            return _buildNoDevicesScreen();
          }

          final primaryDevice = _getPrimaryDevice(devices);

          if (primaryDevice != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (context) => GPSMapScreen(deviceId: primaryDevice.name),
                ),
              );
            });

            return const LoadingScreen(message: 'Initializing GPS tracking...');
          }

          return _buildNoValidDevicesScreen();
        },
      ),
    );
  }

  Device? _getPrimaryDevice(List<Device> devices) {
    // Priority: Active devices with valid GPS coordinates
    final activeWithGPS = devices.where((d) => d.isActive && d.hasValidGPS);
    if (activeWithGPS.isNotEmpty) {
      return activeWithGPS.first;
    }

    // Fallback: Any active device
    final activeDevices = devices.where((d) => d.isActive);
    if (activeDevices.isNotEmpty) {
      return activeDevices.first;
    }

    // Last resort: Any device
    return devices.isNotEmpty ? devices.first : null;
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Error'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to load devices',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ErrorCard(message: error, onRetry: () => setState(() {})),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDevicesScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.device_hub, size: 64, color: Colors.blue.shade600),
              const SizedBox(height: 24),
              Text(
                'No GPS Devices Found',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'You need to add a GPS tracking device to use this app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/device');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoValidDevicesScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Setup'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber,
                size: 64,
                color: Colors.orange.shade600,
              ),
              const SizedBox(height: 24),
              Text(
                'No Active Devices',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your devices are not actively sending GPS data. Please check your device connections.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/device');
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
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
      title: 'VelTr',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PlusJakarta',
        colorScheme: AppTheme.lightTheme.colorScheme,
        appBarTheme: AppTheme.lightTheme.appBarTheme,
        cardTheme: AppTheme.lightTheme.cardTheme,
        elevatedButtonTheme: AppTheme.lightTheme.elevatedButtonTheme,
        outlinedButtonTheme: AppTheme.lightTheme.outlinedButtonTheme,
        textTheme: AppTheme.lightTheme.textTheme.apply(
          fontFamily: 'PlusJakarta',
        ),
        primaryTextTheme: AppTheme.lightTheme.primaryTextTheme.apply(
          fontFamily: 'PlusJakarta',
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'PlusJakarta',
        colorScheme: AppTheme.darkTheme.colorScheme,
        appBarTheme: AppTheme.darkTheme.appBarTheme,
        cardTheme: AppTheme.darkTheme.cardTheme,
        elevatedButtonTheme: AppTheme.darkTheme.elevatedButtonTheme,
        outlinedButtonTheme: AppTheme.darkTheme.outlinedButtonTheme,
        textTheme: AppTheme.darkTheme.textTheme.apply(
          fontFamily: 'PlusJakarta',
        ),
        primaryTextTheme: AppTheme.darkTheme.primaryTextTheme.apply(
          fontFamily: 'PlusJakarta',
        ),
      ),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routes: _buildRoutes(),
      home: _buildAuthenticationFlow(),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/login': (context) => const LoginScreen(),
      '/registerone': (context) => const RegisterOne(),
      '/google-signup': (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, String>;
        return GoogleSignupScreen(
          email: args['email']!,
          displayName: args['displayName']!,
        );
      },
      '/home': (context) => const DeviceRouterScreen(),
      '/profile': (context) => const ProfilePage(),
      '/edit-profile': (context) => const EditProfileScreen(),
      '/notifications': (context) => const NotificationsScreen(),
      '/vehicle': (context) => const VehicleIndexScreen(),
      '/manage-vehicle': (context) => const ManageVehicle(),
      '/drive-history': (context) => const DrivingHistory(),
      '/device': (context) => const DeviceManagerScreen(),
      '/geofence': (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final deviceId = args?['deviceId'] as String?;
        return deviceId != null
            ? GeofenceListScreen(deviceId: deviceId)
            : const DeviceRouterScreen();
      },
      '/set-range': (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final deviceId = args?['deviceId'] as String?;
        return deviceId != null
            ? DeviceListScreen(deviceId: deviceId)
            : const DeviceRouterScreen();
      },
    };
  }

  Widget _buildAuthenticationFlow() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(
            message: 'Checking authentication status...',
          );
        }
        return snapshot.hasData
            ? const DeviceRouterScreen()
            : const LoginScreen();
      },
    );
  }
}

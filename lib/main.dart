import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:provider/provider.dart'; // Temporarily commented out
import 'firebase_options.dart';
import 'themes/app_theme.dart';

// Screen imports
import 'screens/Auth/login.dart';
import 'screens/Auth/RegisterOne.dart';
import 'screens/Auth/GoogleSignupScreen.dart';
import 'screens/Auth/change_password_screen.dart';
import 'screens/Users/Profile.dart';
import 'screens/users/edit_profile.dart';
import 'screens/Vehicle/index.dart';
import 'screens/vehicle/manage.dart';
import 'screens/vehicle/history.dart';
import 'screens/Maps/mapView.dart';
import 'screens/GeoFence/index.dart';
import 'screens/GeoFence/device_geofence.dart';
import 'screens/device/index.dart';
import 'screens/notifications/enhanced_notifications_screen.dart';

// Widget Imports
import 'widgets/Common/loading_screen.dart';
import 'widgets/Common/error_card.dart';

// Service imports
import 'services/notifications/enhanced_notification_service.dart';
import 'services/geofence/geofence_alert_service.dart';
import 'services/device/deviceService.dart';
import 'services/history/history_service.dart';

// Model imports
import 'models/Device/device.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 [MAIN] Starting Firebase initialization...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('✅ [MAIN] Firebase initialized successfully');

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize enhanced notification service FIRST (this will handle ALL FCM messages)
  final notificationService = EnhancedNotificationService();
  await notificationService.initialize();
  
  // Initialize geofence alert service WITHOUT FCM handlers (to prevent duplicates)
  final geofenceAlertService = GeofenceAlertService();
  await geofenceAlertService.initializeWithoutFCM(); // We'll create this method

  // Initialize history service
  HistoryService.initialize();

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

          // Always navigate to map view regardless of device availability
          // The map will handle no-device scenarios internally
          final primaryDevice = _getPrimaryDevice(
            devices,
          ); // Use primary device if available, otherwise use placeholder
          final deviceId = primaryDevice?.id ?? 'no_device_placeholder';
          debugPrint('🚀 [DEVICE_ROUTER] Device selection logic:');
          debugPrint(
            '🚀 [DEVICE_ROUTER] Total devices found: ${devices.length}',
          );
          debugPrint(
            '🚀 [DEVICE_ROUTER] Primary device selected: ${primaryDevice?.id ?? "none"} (name: ${primaryDevice?.name ?? "none"})',
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

    // CRITICAL: Only consider devices that are linked to vehicles
    final linkedDevices =
        devices
            .where((d) => d.vehicleId != null && d.vehicleId!.isNotEmpty)
            .toList();

    debugPrint(
      '🎯 [DEVICE_SELECTION] Devices linked to vehicles: ${linkedDevices.length}',
    );

    if (linkedDevices.isEmpty) {
      debugPrint(
        '🚫 [DEVICE_SELECTION] No devices linked to vehicles - returning null',
      );
      return null;
    }

    // Priority: Active linked devices with valid GPS coordinates
    final activeLinkedWithGPS = linkedDevices.where(
      (d) => d.isActive && d.hasValidGPS,
    );
    debugPrint(
      '🎯 [DEVICE_SELECTION] Active linked devices with GPS: ${activeLinkedWithGPS.length}',
    );

    if (activeLinkedWithGPS.isNotEmpty) {
      final selected = activeLinkedWithGPS.first;
      debugPrint(
        '🎯 [DEVICE_SELECTION] Selected linked device with GPS: ${selected.name} (vehicleId: ${selected.vehicleId})',
      );
      return selected;
    }

    // Fallback: Any active linked device
    final activeLinkedDevices = linkedDevices.where((d) => d.isActive);
    debugPrint(
      '🎯 [DEVICE_SELECTION] Active linked devices (any): ${activeLinkedDevices.length}',
    );

    if (activeLinkedDevices.isNotEmpty) {
      final selected = activeLinkedDevices.first;
      debugPrint(
        '🎯 [DEVICE_SELECTION] Selected active linked device: ${selected.name} (vehicleId: ${selected.vehicleId})',
      );
      return selected;
    }

    // Last resort: Any linked device
    final anyLinkedDevice =
        linkedDevices.isNotEmpty ? linkedDevices.first : null;
    debugPrint(
      '🎯 [DEVICE_SELECTION] Last resort linked device: ${anyLinkedDevice?.name ?? "none"} (vehicleId: ${anyLinkedDevice?.vehicleId ?? "none"})',
    );
    return anyLinkedDevice;
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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Temporarily commented out for local vehicle selector implementation
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(
    //       create: (context) => VehicleProvider()..initialize(),
    //     ),
    //   ],
    //   child: MaterialApp(
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
      '/login': (context) => const LoginScreen(),      '/change-password': (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
        final email = args?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        return ChangePasswordScreen(email: email);
      },
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
      '/notifications': (context) => const EnhancedNotificationsScreen(),
      '/vehicle': (context) => const VehicleIndexScreen(),
      '/manage-vehicle': (context) => const ManageVehicle(),
      '/drive-history': (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null &&
            args['vehicleId'] != null &&
            args['vehicleName'] != null) {
          return DrivingHistory(
            vehicleId: args['vehicleId'] as String,
            vehicleName: args['vehicleName'] as String,
          );
        }
        // If no specific vehicle is selected, use the first available vehicle
        // The DrivingHistory screen will handle vehicle selection internally
        return const DrivingHistory(vehicleId: '', vehicleName: '');
      },
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

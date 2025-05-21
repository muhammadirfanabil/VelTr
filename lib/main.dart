import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gps_app/screens/Auth/RegisterOne.dart';
import 'package:gps_app/screens/Auth/RegisterTwo.dart';
import 'package:gps_app/screens/Users/Profile.dart';

import 'firebase_options.dart';
import 'screens/Auth/login.dart';
// import 'screens/Users/index.dart';
import 'screens/Vehicle/index.dart';
import 'screens/Maps/mapView.dart';
import 'screens/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        '/registertwo': (context) => const RegisterTwo(),
        '/registerone': (context) => const RegisterOne(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const IndexScreen(),
        // '/': (context) => const IndexScreen(),
        '/map': (context) => const GPSMapScreen(),
        // '/users': (context) => const UsersListScreen(),
        '/vehicle': (context) => const VehicleIndexScreen(),
        '/profile': (context) => const ProfilePage(),
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

          return const IndexScreen();
        },
      ),
    );
  }
}

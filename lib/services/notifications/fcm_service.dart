import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase sudah diinisialisasi di isolate background
  await Firebase.initializeApp();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  if (message.notification != null) {
    final notification = message.notification!;
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
    );
  }
}

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initFCM() async {
    // Minta izin notifikasi
    await _firebaseMessaging.requestPermission();

    // Inisialisasi plugin notifikasi lokal
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    // Buat channel notifikasi (penting untuk Android 13+)
    const androidChannel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Notifications',
      description: 'Notifikasi masuk atau keluar area geofence',
      importance: Importance.high,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Ambil dan simpan token FCM
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(uid)
            .update({
              'fcmToken': token,
              'token_updated_at': FieldValue.serverTimestamp(),
            });
      }
    }

    // Simpan ulang jika token berubah
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(uid)
            .update({
              'fcmToken': newToken,
              'token_updated_at': FieldValue.serverTimestamp(),
            });
      }
    });

    // Handle notifikasi saat app di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final title = message.notification!.title ?? 'Notifikasi';
        final body = message.notification!.body ?? '';
        _showLocalNotification(title, body);
      }
    });

    // Opsional: Saat notifikasi diklik dan membuka aplikasi
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Notifikasi dibuka: ${message.data}");
      // Kamu bisa navigasi ke halaman tertentu jika perlu
    });
  }

  void _showLocalNotification(String title, String body) {
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    _flutterLocalNotificationsPlugin.show(
      0, // ID notifikasi
      title,
      body,
      notificationDetails,
    );
  }
}

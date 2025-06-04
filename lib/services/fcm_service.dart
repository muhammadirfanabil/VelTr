import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initializeFCM(String deviceId) async {
    try {
      final token = await _messaging.getToken();

      if (token != null) {
        await _saveTokenToGeofence(deviceId, token);

        // Dengarkan perubahan token
        _messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToGeofence(deviceId, newToken);
        });
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToGeofence(String deviceId, String token) async {
    final geofences =
        await FirebaseFirestore.instance
            .collection('geofences')
            .where('deviceId', isEqualTo: deviceId)
            .get();

    for (var doc in geofences.docs) {
      await doc.reference.update({'fcmToken': token});
    }
  }
}

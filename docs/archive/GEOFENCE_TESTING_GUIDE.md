# 🧪 Geofence Notification Testing Guide

## Issues Fixed ✅

1. **Firestore Index**: Created composite index for notifications query
2. **Cloud Function Trigger**: Changed from Firestore to Realtime Database trigger
3. **Function Deployment**: Successfully deployed updated functions

## 📋 Step-by-Step Testing Process

### **Phase 1: Verify Setup**

#### **Step 1: Check Function Deployment**

```bash
firebase functions:list
```

Should show `geofencechangestatus` with **database trigger**.

#### **Step 2: Check Firestore Indexes**

- Go to Firebase Console → Firestore → Indexes
- Should see index for `notifications` collection with fields: `ownerId`, `timestamp`

### **Phase 2: Create Test Data**

#### **Step 3: Add Test Device in Realtime Database**

Go to Firebase Console → Realtime Database and create:

```json
{
  "devices": {
    "TEST_DEVICE_001": {
      "gps": {
        "latitude": -6.2,
        "longitude": 106.816666,
        "timestamp": 1703123456789,
        "speed": 0
      }
    }
  }
}
```

#### **Step 4: Create User and Device in Firestore**

Create these documents in Firestore:

**Collection: `users`**

```json
// Document ID: YOUR_USER_ID (from Firebase Auth)
{
  "fcmTokens": ["your-fcm-token-here"],
  "email": "test@example.com",
  "name": "Test User"
}
```

**Collection: `devices`**

```json
// Document ID: TEST_DEVICE_001
{
  "deviceId": "TEST_DEVICE_001",
  "deviceName": "Test Vehicle",
  "ownerId": "YOUR_USER_ID"
}
```

**Collection: `geofences`**

```json
// Auto-generated document ID
{
  "name": "Test Zone",
  "deviceId": "TEST_DEVICE_001",
  "ownerId": "YOUR_USER_ID",
  "points": [
    { "latitude": -6.199, "longitude": 106.815 },
    { "latitude": -6.201, "longitude": 106.815 },
    { "latitude": -6.201, "longitude": 106.817 },
    { "latitude": -6.199, "longitude": 106.817 }
  ],
  "status": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### **Phase 3: Test Notifications**

#### **Step 5: Test Vehicle ENTERS Geofence**

Update GPS in Realtime Database:

```json
{
  "devices": {
    "TEST_DEVICE_001": {
      "gps": {
        "latitude": -6.2, // Inside geofence
        "longitude": 106.816,
        "timestamp": 1703123500000,
        "speed": 25
      }
    }
  }
}
```

**Expected:**

- Cloud Function executes
- Notification appears on your device
- Entry logged in Firestore `notifications` collection

#### **Step 6: Test Vehicle EXITS Geofence**

Update GPS again:

```json
{
  "devices": {
    "TEST_DEVICE_001": {
      "gps": {
        "latitude": -6.205, // Outside geofence
        "longitude": 106.82,
        "timestamp": 1703123600000,
        "speed": 30
      }
    }
  }
}
```

**Expected:**

- Exit notification appears
- Exit event logged in Firestore

### **Phase 4: Debug Issues**

#### **Step 7: Check Function Logs**

```bash
firebase functions:log --only geofencechangestatus
```

Look for:

- ✅ "Starting status check for device: TEST_DEVICE_001"
- ✅ "Valid coordinates: lat, lng"
- ✅ "Device entered/exited geofence"
- ❌ Any error messages

#### **Step 8: Check Firestore Data**

Verify these collections have data:

- `notifications` - Should contain geofence alerts
- `geofence_logs` - Should contain detailed logs

#### **Step 9: Check FCM Token**

In your Flutter app, check if FCM token is properly saved:

```dart
// This should happen automatically when app starts
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### **Phase 5: Flutter App Testing**

#### **Step 10: Test Notification Display**

1. Open your Flutter app
2. Navigate to notifications screen
3. Should see geofence alerts listed
4. Test mark as read functionality

#### **Step 11: Test Real-time Updates**

1. Keep app open on notifications screen
2. Trigger geofence event (update GPS)
3. Should see new notification appear instantly

## 🐛 Troubleshooting

### **No Function Logs:**

- Check if function is triggered on Realtime Database changes
- Verify GPS data structure in RTDB

### **No Notifications in App:**

- Check FCM token exists in Firestore users collection
- Verify notification permissions granted

### **Index Errors:**

- Wait 2-3 minutes for index to build
- Check Firebase Console → Firestore → Indexes

### **Function Errors:**

- Check function logs for specific error messages
- Verify all required Firestore collections exist

## ✅ Success Criteria

Your system works when:

1. Function executes on GPS updates (check logs)
2. Geofence detection works (inside/outside)
3. FCM notifications sent and received
4. Firestore contains notification records
5. Flutter app displays notifications
6. Real-time updates work

After completing this test, your geofence notification system should be fully operational! 🎉

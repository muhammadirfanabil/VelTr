# 🔧 VEHICLE STATUS NOTIFICATION TROUBLESHOOTING GUIDE

## 🎯 ISSUE: Vehicle Status Notifications Not Working

### ✅ CURRENT STATUS

Both **vehicle status** and **geofence** notifications are now properly implemented with:

- **Visible notification payloads** (appear in phone notification tray)
- **Data payloads** (for in-app handling)
- **Android/iOS styling** (icons, colors, sounds, vibration)
- **Consistent structure** between both notification types
- **Token validation and cleanup**

## 🔍 DEBUGGING STEPS

### Step 1: Check FCM Tokens

Run the debug script to verify FCM tokens:

```bash
cd "d:\Kuliah\Tugas Akhir\VelTr"
node debug_fcm_tokens.js <USER_ID>
```

Replace `<USER_ID>` with a real user ID from your `users_information` collection.

**Expected output:**

```
✅ User found
📱 FCM Tokens: 1 (or more)
📱 Token 1:
   ✅ Token is VALID
📊 Token Summary:
   Valid tokens: 1
   Invalid tokens: 0
```

### Step 2: Test Vehicle Status Notification

Use the Cloud Function to test:

```javascript
// In your app or Firebase console
firebase
  .functions()
  .httpsCallable("testvehiclestatusnotification")({
    deviceId: "TEST_DEVICE",
    action: "on", // or "off"
  })
  .then((result) => {
    console.log("Test result:", result.data);
  });
```

### Step 3: Check Cloud Function Logs

Monitor the logs when testing:

```bash
firebase functions:log --only vehiclestatusmonitor,testvehiclestatusnotification
```

**Look for these log messages:**

```
✅ [VEHICLE_NOTIFICATION] Sent to 1/1 tokens
📱 [VEHICLE_NOTIFICATION] Sending on notification for "Vehicle Name"
🔔 [VEHICLE_NOTIFICATION] Preparing notification: "Vehicle Status Update" - "..."
```

### Step 4: Verify Database Storage

Check if notifications are being stored in Firestore:

1. Open Firebase Console
2. Go to Firestore Database
3. Check `notifications` collection
4. Look for recent entries with `type: "vehicle_status"`

### Step 5: Test Real Vehicle Status Change

Trigger a real relay change in the database:

```bash
# Use the manual relay test function
firebase.functions().httpsCallable('testmanualrelay')({
  deviceId: "YOUR_DEVICE_ID",
  action: "on" // or "off"
})
```

## ❗ COMMON ISSUES & SOLUTIONS

### Issue 1: No FCM Tokens Found

**Symptoms:** `No FCM tokens found for user`
**Solution:**

- Ensure user has logged into the mobile app
- Verify FCM tokens are stored in `users_information/{userId}/fcmTokens` array
- Check if FCM setup is correct in the mobile app

### Issue 2: Invalid FCM Tokens

**Symptoms:** `Failed to send to token: ... messaging/registration-token-not-registered`
**Solution:**

- Run the debug script to identify invalid tokens
- Invalid tokens are automatically cleaned up by the function
- User needs to restart the app to generate new tokens

### Issue 3: Device Not Found

**Symptoms:** `Device not found with name: {deviceId}`
**Solution:**

- Verify device exists in `devices` collection
- Check if device `name` field matches the deviceId from RTDB path
- Ensure device has proper `ownerId` field

### Issue 4: No Notification Channel

**Symptoms:** Notification sent but not visible on phone
**Solution:**

- Mobile app must create notification channels:
  - `vehicle_status_channel` for vehicle notifications
  - `geofence_alerts_channel` for geofence notifications
- Check Android notification channel setup in the app

### Issue 5: Notification Permissions

**Symptoms:** Notifications not appearing despite successful FCM send
**Solution:**

- Ensure app has notification permissions on the device
- Check if "Do Not Disturb" mode is enabled
- Verify notification settings for the app in phone settings

## 📱 NOTIFICATION PAYLOAD STRUCTURE

### Vehicle Status Notification:

```json
{
  "notification": {
    "title": "Vehicle Status Update",
    "body": "Vehicle Name (Device) has been successfully turned on."
  },
  "data": {
    "type": "vehicle_status",
    "deviceId": "device_firestore_id",
    "deviceName": "Device Name",
    "vehicleName": "Vehicle Name",
    "relayStatus": "true",
    "statusText": "on",
    "actionText": "turned on",
    "timestamp": "2024-01-15T10:30:00Z",
    "title": "Vehicle Status Update",
    "body": "Vehicle Name (Device) has been successfully turned on."
  },
  "android": {
    "priority": "high",
    "notification": {
      "icon": "ic_notification",
      "color": "#4CAF50", // Green for ON, Red (#F44336) for OFF
      "channelId": "vehicle_status_channel",
      "defaultSound": true,
      "defaultVibrateTimings": true
    }
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": {
          "title": "Vehicle Status Update",
          "body": "Vehicle Name (Device) has been successfully turned on."
        },
        "sound": "default",
        "badge": 1,
        "contentAvailable": true
      }
    }
  }
}
```

## 🔄 TESTING WORKFLOW

### For Development:

1. **Debug FCM Tokens** → `node debug_fcm_tokens.js <USER_ID>`
2. **Test Function** → Call `testvehiclestatusnotification`
3. **Check Logs** → Monitor Cloud Function logs
4. **Verify Database** → Check `notifications` collection
5. **Test on Phone** → Verify notification appears

### For Production:

1. **Real Status Change** → Change relay status in RTDB
2. **Monitor Logs** → Watch `vehiclestatusmonitor` function
3. **Check Cooldown** → Ensure 1-minute cooldown is respected
4. **Verify Delivery** → Confirm notification appears on user's phone

## 🚨 ESCALATION CHECKLIST

If notifications still don't work after following this guide:

### Backend Checklist:

- [ ] Cloud Functions deployed successfully
- [ ] FCM tokens exist and are valid
- [ ] Device exists in Firestore with correct `ownerId`
- [ ] Notification is stored in database
- [ ] No errors in Cloud Function logs

### Mobile App Checklist:

- [ ] FCM properly initialized
- [ ] Notification channels created
- [ ] Notification permissions granted
- [ ] FCM tokens properly stored in database
- [ ] App handles both foreground and background notifications

### Device Checklist:

- [ ] Internet connection available
- [ ] Notification permissions enabled for app
- [ ] Do Not Disturb mode disabled
- [ ] App not in battery optimization/sleep mode

## 📞 SUPPORT

If all checks pass but notifications still don't work:

1. Provide Cloud Function logs
2. Share FCM token debug output
3. Include device information (Android/iOS version)
4. Test with multiple devices/users

The implementation is technically correct and should work. Issues are likely related to:

- Mobile app notification setup
- Device-specific notification settings
- FCM token management

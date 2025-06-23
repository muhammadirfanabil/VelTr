# Geofence Status Detection System - Testing Guide

## Overview

This guide provides comprehensive testing procedures for the rebuilt geofence status detection system. The system has been completely rebuilt with improved reliability, robust GPS validation, accurate polygon detection, and comprehensive FCM notification delivery.

## Key Features of the Rebuilt System

### 🔧 Core Improvements

- **Robust GPS Validation**: Handles multiple field formats and validates coordinate ranges
- **Enhanced Point-in-Polygon Detection**: Uses ray-casting algorithm with improved error handling
- **Comprehensive FCM Integration**: Full push notification support with token management
- **Detailed Logging**: Complete audit trail of all geofence events
- **Error Recovery**: Graceful handling of malformed data and network issues

### 📱 Notification Features

- Real-time push notifications via Firebase Cloud Messaging
- Automatic FCM token cleanup for invalid tokens
- Notification history logging in Firestore
- Custom notification channels for Android
- Proper APNs configuration for iOS

## Testing Checklist

### 1. Prerequisites Verification

#### ✅ Firebase Configuration

- [ ] Verify Firebase project is properly configured
- [ ] Confirm Cloud Functions are deployed in `asia-southeast1` region
- [ ] Check that FCM is enabled and configured
- [ ] Ensure Firestore has proper security rules

#### ✅ Required Collections

- [ ] `devices` collection exists with proper structure
- [ ] `geofences` collection has active geofences
- [ ] `users` collection contains FCM tokens
- [ ] `geofence_logs` collection is accessible
- [ ] `notifications` collection is set up

### 2. Function Deployment Verification

```bash
# Check deployed functions
firebase functions:list

# Expected functions:
# - geofencechangestatus (Firestore trigger)
# - querygeofencelogs (HTTP callable)
# - getgeofencestats (HTTP callable)
```

### 3. GPS Data Validation Testing

#### Test Valid GPS Formats

The system should handle these GPS data formats:

```javascript
// Format 1: Standard latitude/longitude
{
  "latitude": -6.2088,
  "longitude": 106.8456
}

// Format 2: lat/lng format
{
  "lat": -6.2088,
  "lng": 106.8456
}

// Format 3: lat/lon format
{
  "lat": -6.2088,
  "lon": 106.8456
}

// Format 4: Nested location object
{
  "location": {
    "latitude": -6.2088,
    "longitude": 106.8456
  }
}

// Format 5: String coordinates (should be converted)
{
  "latitude": "-6.2088",
  "longitude": "106.8456"
}
```

#### Test Invalid GPS Data

- [ ] Missing coordinates
- [ ] NaN values
- [ ] Out of range coordinates (lat > 90, lng > 180)
- [ ] Non-numeric values
- [ ] Null/undefined values

### 4. Geofence Detection Testing

#### Test Scenarios

##### Scenario 1: Enter Geofence

1. **Setup**: Create a geofence with known coordinates
2. **Action**: Send GPS data from outside the geofence
3. **Action**: Send GPS data from inside the geofence
4. **Expected**:
   - Function triggers on GPS data
   - Detects status change from outside to inside
   - Logs entry event to `geofence_logs`
   - Sends FCM notification with "entered" status

##### Scenario 2: Exit Geofence

1. **Setup**: Device is already inside geofence (from previous test)
2. **Action**: Send GPS data from outside the geofence
3. **Expected**:
   - Detects status change from inside to outside
   - Logs exit event to `geofence_logs`
   - Sends FCM notification with "exited" status

##### Scenario 3: No Status Change

1. **Action**: Send GPS data from same status (inside/outside)
2. **Expected**:
   - Function processes data
   - No status change detected
   - No notification sent
   - No log entry created

### 5. FCM Notification Testing

#### Pre-requisites

- [ ] User has valid FCM token(s) in Firestore
- [ ] Mobile app is installed and can receive notifications
- [ ] Notification permissions are granted

#### Test Cases

##### Valid FCM Token

1. **Setup**: Ensure user has valid FCM token
2. **Trigger**: Cause geofence entry/exit
3. **Expected**:
   - Notification sent successfully
   - User receives push notification
   - Notification logged in `notifications` collection

##### Invalid FCM Token

1. **Setup**: Add invalid/expired FCM token to user
2. **Trigger**: Cause geofence entry/exit
3. **Expected**:
   - Function attempts to send notification
   - Invalid token detected and removed
   - Valid tokens still receive notifications
   - Token cleanup logged

##### Multiple FCM Tokens

1. **Setup**: User has multiple FCM tokens (multiple devices)
2. **Trigger**: Cause geofence entry/exit
3. **Expected**:
   - Notification sent to all valid tokens
   - Invalid tokens removed
   - Success count logged

### 6. Database Logging Verification

#### Geofence Logs Structure

```javascript
{
  "deviceId": "device123",
  "deviceName": "My Vehicle",
  "geofenceId": "geofence456",
  "geofenceName": "Home",
  "ownerId": "user789",
  "action": "enter", // or "exit"
  "status": "inside", // or "outside"
  "location": {
    "latitude": -6.2088,
    "longitude": 106.8456
  },
  "timestamp": "2025-06-17T10:30:00Z",
  "createdAt": "2025-06-17T10:30:00Z",
  "processedAt": "2025-06-17T10:30:01Z"
}
```

#### Notification Logs Structure

```javascript
{
  "ownerId": "user789",
  "deviceId": "device123",
  "deviceName": "My Vehicle",
  "geofenceName": "Home",
  "action": "enter",
  "message": "My Vehicle has entered Home",
  "location": {
    "latitude": -6.2088,
    "longitude": 106.8456
  },
  "timestamp": "2025-06-17T10:30:00Z",
  "createdAt": "2025-06-17T10:30:00Z",
  "read": false,
  "sentToTokens": 2,
  "totalTokens": 2
}
```

### 7. Performance and Scalability Testing

#### Load Testing

- [ ] Test with multiple devices triggering simultaneously
- [ ] Test with large geofence polygons (many points)
- [ ] Test with many geofences for single device
- [ ] Monitor function execution time and memory usage

#### Error Handling

- [ ] Test with malformed GPS data
- [ ] Test with missing device/user data
- [ ] Test with Firestore connection issues
- [ ] Test with FCM service unavailable

### 8. End-to-End Testing Procedure

#### Step 1: Setup Test Environment

```javascript
// Create test device in Firestore
await db.collection("devices").doc("test-device-123").set({
  name: "Test Vehicle",
  ownerId: "test-user-456",
});

// Create test user with FCM token
await db
  .collection("users")
  .doc("test-user-456")
  .set({
    fcmTokens: ["your-test-fcm-token-here"],
  });

// Create test geofence
await db
  .collection("geofences")
  .doc("test-geofence-789")
  .set({
    name: "Test Geofence",
    deviceId: "test-device-123",
    ownerId: "test-user-456",
    status: true,
    points: [
      { latitude: -6.208, longitude: 106.845 },
      { latitude: -6.209, longitude: 106.845 },
      { latitude: -6.209, longitude: 106.846 },
      { latitude: -6.208, longitude: 106.846 },
    ],
  });
```

#### Step 2: Test Geofence Entry

```javascript
// Send GPS data from outside geofence
await db.collection("devices").doc("test-device-123").collection("gps").add({
  latitude: -6.207, // Outside geofence
  longitude: 106.844,
  timestamp: new Date(),
});

// Wait and verify no notification (baseline)

// Send GPS data from inside geofence
await db.collection("devices").doc("test-device-123").collection("gps").add({
  latitude: -6.2085, // Inside geofence
  longitude: 106.8455,
  timestamp: new Date(),
});

// Verify entry notification received
```

#### Step 3: Test Geofence Exit

```javascript
// Send GPS data from outside geofence
await db.collection("devices").doc("test-device-123").collection("gps").add({
  latitude: -6.207, // Outside geofence
  longitude: 106.844,
  timestamp: new Date(),
});

// Verify exit notification received
```

### 9. Monitoring and Debugging

#### Cloud Functions Logs

```bash
# View function logs
firebase functions:log --only geofencechangestatus

# Follow logs in real-time
firebase functions:log --only geofencechangestatus --follow
```

#### Log Patterns to Monitor

- ✅ `🎯 [GEOFENCE] Starting status check` - Function triggered
- ✅ `📍 [GPS] Valid coordinates` - GPS validation successful
- ✅ `🔍 [GEOFENCES] Found X active geofences` - Geofence query successful
- ✅ `🚨 [CHANGE DETECTED] ENTER/EXIT detected` - Status change identified
- ✅ `📱 [FCM] Notification sent` - FCM notification successful
- ✅ `✅ [COMMIT] Logged X status changes` - Database logging successful

#### Error Patterns to Watch

- ❌ `❌ [VALIDATION]` - GPS validation failed
- ❌ `❌ [DEVICE] Device not found` - Device lookup failed
- ❌ `❌ [FCM] Failed to send` - FCM delivery failed
- ❌ `❌ [ERROR] Processing failed` - General function error

### 10. Performance Expectations

#### Function Performance

- **Cold Start**: < 3 seconds
- **Warm Execution**: < 1 second
- **Memory Usage**: < 100MB
- **Timeout**: 60 seconds (default)

#### Notification Delivery

- **FCM Delivery**: < 2 seconds
- **Multiple Tokens**: < 5 seconds
- **Retry Logic**: Automatic for transient failures

## Troubleshooting Common Issues

### Issue: Function Not Triggering

1. Check Firestore trigger path: `devices/{deviceId}/gps/{gpsId}`
2. Verify function is deployed in correct region
3. Check Firebase project permissions

### Issue: GPS Validation Failing

1. Check GPS data format in function logs
2. Verify coordinate values are within valid ranges
3. Ensure data types are correct (numbers, not strings)

### Issue: Notifications Not Received

1. Verify FCM token is valid and current
2. Check user's notification permissions
3. Verify FCM service key configuration
4. Check app is in foreground/background handling

### Issue: Polygon Detection Incorrect

1. Verify geofence polygon has minimum 3 points
2. Check coordinate system consistency (lat/lng vs lng/lat)
3. Validate polygon is not self-intersecting
4. Test with simple rectangular geofence first

## Success Criteria

The rebuilt geofence system is considered successful when:

1. **✅ Reliability**: 99%+ success rate for valid GPS data
2. **✅ Accuracy**: Correct detection of geofence entry/exit events
3. **✅ Performance**: Function execution under 1 second for warm starts
4. **✅ Notifications**: FCM delivery within 2 seconds
5. **✅ Logging**: Complete audit trail of all events
6. **✅ Error Handling**: Graceful handling of edge cases
7. **✅ Scalability**: Support for multiple devices and geofences

## Next Steps

After successful testing:

1. **Production Deployment**: Deploy to production environment
2. **Monitoring Setup**: Configure alerts for function failures
3. **User Training**: Update documentation for end users
4. **Performance Monitoring**: Set up ongoing performance tracking
5. **Feature Enhancement**: Consider additional features like scheduling, multiple notification types, etc.

---

**Last Updated**: June 17, 2025
**Version**: 1.0 (Rebuilt System)
**Status**: Ready for Testing

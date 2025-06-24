# FCM Token Management Standard

## Overview

This document outlines the standardized Firebase Cloud Messaging (FCM) token management approach implemented in the GPS app. The new system ensures consistent token handling across all authentication flows and provides better support for multi-device usage.

## Problem Statement

Previously, the FCM token management was inconsistent across the application:

- **Multiple implementations**: Different services (`FCMService`, `EnhancedNotificationService`, `GeofenceAlertService`) each managed tokens independently
- **Inconsistent field usage**: Some services used `fcmToken` (single string), others used `fcmTokens` (array)
- **No automatic token saving**: Tokens were not automatically saved during login/registration flows
- **Missing user document handling**: No guarantee that user documents existed when saving tokens
- **No token cleanup**: Tokens were not removed during logout

## New Standardized Approach

### 1. Centralized Token Management

FCM token management is now centralized in the `AuthService` class (`lib/services/auth/authService.dart`). This ensures:

- **Single source of truth**: All token operations go through one service
- **Consistent implementation**: Same logic applied across all authentication flows
- **Automatic token management**: Tokens are saved/removed automatically during auth events

### 2. Consistent Data Structure

All FCM tokens are now stored using the **`fcmTokens` array field** in Firestore:

```typescript
// User document structure in Firestore
{
  name: string,
  email: string,
  phone_number: string,
  address: string,
  fcmTokens: string[],  // Array of FCM tokens (supports multiple devices)
  fcm_token_updated_at: Timestamp,
  fcm_token_removed_at: Timestamp,
  created_at: Timestamp,
  // ... other fields
}
```

**Benefits of using arrays:**

- **Multi-device support**: Users can receive notifications on multiple devices
- **No token conflicts**: Array union prevents duplicates
- **Cloud Functions compatibility**: Arrays are easier to iterate in Cloud Functions
- **Future-proof**: Supports advanced features like device-specific targeting

### 3. Automatic Token Lifecycle Management

#### On Login/Registration

```dart
// Automatically called after successful authentication
await _initializeFCMTokenManagement();
```

This method:

1. Requests notification permissions
2. Gets the current FCM token
3. Saves token to `fcmTokens` array using `FieldValue.arrayUnion()`
4. Sets up token refresh listener
5. Uses `SetOptions(merge: true)` to create user document if needed

#### On Token Refresh

```dart
FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
  _saveFCMToken(); // Automatically updates Firestore
});
```

#### On Logout

```dart
await _removeFCMToken(); // Removes current device token
await FirebaseAuth.instance.signOut();
```

## Implementation Details

### AuthService Methods

#### `_initializeFCMTokenManagement()`

- **Purpose**: Initialize FCM token management for authenticated users
- **When called**: After successful login/registration
- **Actions**:
  - Request notification permissions
  - Get and save current FCM token
  - Set up token refresh listener

#### `_saveFCMToken()`

- **Purpose**: Save or update FCM token in user's Firestore document
- **Storage method**: Uses `FieldValue.arrayUnion()` to prevent duplicates
- **Document creation**: Uses `SetOptions(merge: true)` to create user document if missing
- **Error handling**: Gracefully handles failures without breaking auth flow

#### `_removeFCMToken()`

- **Purpose**: Remove FCM token from user's Firestore document on logout
- **Storage method**: Uses `FieldValue.arrayRemove()` to remove specific token
- **When called**: Before user logout to clean up device-specific tokens

### Updated Authentication Flows

#### Email/Password Login

```dart
static Future<UserCredential> loginWithEmail(String email, String password) async {
  final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  // FCM token management added here
  await _initializeFCMTokenManagement();

  return userCredential;
}
```

#### Google Sign-In

```dart
static Future<UserCredential> loginWithGoogle() async {
  // ... existing Google auth logic ...

  // FCM token management added here
  await _initializeFCMTokenManagement();

  return userCredential;
}
```

#### Registration (Email & Google)

Both registration methods now include automatic FCM token management after user document creation.

#### Logout

```dart
static Future<void> signOut() async {
  // Token cleanup added here
  await _removeFCMToken();

  await FirebaseAuth.instance.signOut();
  await GoogleSignIn().signOut();
}
```

## Migration from Old System

### Services Updated

1. **`FCMService`**: Simplified to focus only on notification display, removed token management
2. **`EnhancedNotificationService`**: Removed duplicate token management methods
3. **`GeofenceAlertService`**: Removed FCM token management, relies on AuthService

### Database Field Migration

If you have existing users with `fcmToken` (string) fields, you can migrate them using a Cloud Function:

```typescript
// Example migration function
export const migrateFCMTokens = functions.firestore
  .document("users_information/{userId}")
  .onWrite(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // Check if old fcmToken exists and fcmTokens doesn't
    if (newData?.fcmToken && !newData?.fcmTokens) {
      await change.after.ref.update({
        fcmTokens: [newData.fcmToken],
        fcmToken: admin.firestore.FieldValue.delete(),
      });
    }
  });
```

## Cloud Functions Integration

When sending notifications via Cloud Functions, always use the `fcmTokens` array:

```typescript
// Example Cloud Function for sending notifications
export const sendGeofenceAlert = functions.https.onCall(
  async (data, context) => {
    const { userId, message } = data;

    // Get user's FCM tokens
    const userDoc = await admin
      .firestore()
      .collection("users_information")
      .doc(userId)
      .get();

    const fcmTokens = userDoc.data()?.fcmTokens || [];

    if (fcmTokens.length > 0) {
      // Send to all user's devices
      const payload = {
        notification: {
          title: "Geofence Alert",
          body: message,
        },
      };

      await admin.messaging().sendToDevice(fcmTokens, payload);
    }
  }
);
```

## Testing Guidelines

### Test Cases to Verify

1. **Login Flow**:

   - Login with email/password → Verify `fcmTokens` array contains current token
   - Login with Google → Verify `fcmTokens` array contains current token

2. **Registration Flow**:

   - Register with email → Verify user document created with `fcmTokens`
   - Register with Google → Verify user document created with `fcmTokens`

3. **Token Refresh**:

   - Force token refresh → Verify new token added to `fcmTokens` array

4. **Logout Flow**:

   - Logout → Verify current token removed from `fcmTokens` array

5. **Multi-Device**:
   - Login from multiple devices → Verify each device token in `fcmTokens` array
   - Logout from one device → Verify only that device's token removed

### Manual Testing Steps

1. Clear app data and Firestore user document
2. Register/Login and check Firestore console for proper `fcmTokens` array
3. Logout and verify token removal
4. Test notification delivery to ensure tokens work correctly

## Benefits of New System

1. **Consistency**: Single implementation across all auth flows
2. **Reliability**: Automatic token management prevents missed tokens
3. **Multi-device support**: Array structure supports multiple devices per user
4. **Maintenance**: Centralized logic easier to maintain and debug
5. **Future-proof**: Ready for advanced notification features
6. **Clean data**: Automatic token cleanup on logout
7. **Error resilience**: Graceful handling of token management failures

## Rollback Plan

If issues arise, you can temporarily disable the new token management by:

1. Comment out `_initializeFCMTokenManagement()` calls in AuthService
2. Re-enable the old token management in individual services
3. Update Cloud Functions to use `fcmToken` (string) instead of `fcmTokens` (array)

However, the new system is designed to be backward compatible and should not require rollback.

## Future Enhancements

1. **Token validation**: Periodically validate and clean up invalid tokens
2. **Device management**: Track device information along with tokens
3. **Notification preferences**: Per-device notification settings
4. **Advanced targeting**: Send notifications to specific devices
5. **Analytics**: Track token lifecycle and notification delivery rates

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Author**: Development Team

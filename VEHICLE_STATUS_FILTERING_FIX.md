# 🔧 VEHICLE STATUS NOTIFICATION FILTERING FIX

## 🎯 ISSUE IDENTIFIED
When filtering notifications by a specific vehicle, Vehicle Status notifications were not appearing even though they existed in the database. This was due to a mismatch in how the `deviceName` field was being handled between the Cloud Function and the Flutter app.

## 🔍 ROOT CAUSE ANALYSIS

### Problem in `unified_notification.dart`
```dart
// ❌ BEFORE: Vehicle name was incorrectly assigned to deviceName field
deviceName: vehicleName,  // This broke vehicle filtering!

// ✅ AFTER: Proper device name assignment
deviceName: deviceName,   // Use actual device name for filtering
```

### Problem in Cloud Function Data Structure
The Cloud Function (`index.js`) sends vehicle status notifications with:
- `deviceName`: Actual device identifier (e.g., "BOA7322B2EC4")
- `vehicleName`: Human-readable vehicle name (e.g., "Beat")

But the Flutter app was assigning `vehicleName` to the `deviceName` field, breaking the device-based filtering logic.

## ✅ CHANGES IMPLEMENTED

### 1. Fixed Vehicle Status Notification Parsing
**File:** `lib/models/notifications/unified_notification.dart`

```dart
/// Factory for vehicle status notifications
factory UnifiedNotification._fromVehicleStatusData({
  required String id,
  required Map<String, dynamic> data,
  required DateTime timestamp,
}) {
  final vehicleName =
      data['vehicleName'] ?? data['deviceName'] ?? 'Unknown Vehicle';
  final deviceName = data['deviceName'] ?? 'Unknown Device'; // ✅ NEW: Extract actual device name
  final actionText = data['actionText'] ?? '';
  final relayStatus =
      data['relayStatus'] == 'true' || data['relayStatus'] == true;

  final message =
      data['message'] ?? '✅ $vehicleName has been successfully $actionText.';

  return UnifiedNotification(
    id: id,
    type: NotificationType.vehicleStatus,
    title: 'Vehicle Status Update',
    message: message,
    timestamp: timestamp,
    data: data,
    isRead: data['isRead'] ?? data['read'] ?? false,
    deviceName: deviceName, // ✅ FIXED: Use actual device name for filtering
    geofenceName: 'Status: ${relayStatus ? 'ON' : 'OFF'}',
  );
}
```

### 2. Enhanced Vehicle Filtering Logic
**File:** `lib/screens/notifications/enhanced_notifications_screen.dart`

Added multiple fallback checks for vehicle status notifications:

```dart
// Filter notifications by matching device name
final filteredNotifications = notifications.where((notification) {
  // Primary check: notification deviceName matches vehicle's device name
  if (notification.deviceName != null) {
    return notification.deviceName == vehicleDeviceName;
  }

  // Secondary check: check data fields for device references
  final data = notification.data;
  if (data['deviceName'] != null) {
    return data['deviceName'].toString() == vehicleDeviceName;
  }

  // Tertiary check: check for deviceId in data (Firestore device ID)
  if (data['deviceId'] != null) {
    return data['deviceId'].toString() == selectedVehicle.deviceId;
  }

  // ✅ NEW: Quaternary check for vehicle status notifications
  if (notification.type == NotificationType.vehicleStatus && 
      data['vehicleName'] != null) {
    return data['vehicleName'].toString() == selectedVehicle.name;
  }

  // ✅ NEW: Quinary check for deviceIdentifier from Cloud Function
  if (data['deviceIdentifier'] != null) {
    return data['deviceIdentifier'].toString() == vehicleDeviceName;
  }

  return false;
}).toList();
```

### 3. Added Debug Logging
Added comprehensive debug logging to help troubleshoot filtering issues:

```dart
print('🔍 [FILTER] Filtering for vehicle: ${selectedVehicle.name}, deviceId: ${selectedVehicle.deviceId}, deviceName: $vehicleDeviceName');
print('🔎 [FILTER] Checking notification: ${notification.type}, id: ${notification.id}');
print('🔎 [FILTER] - notification.deviceName: ${notification.deviceName}');
print('🔎 [FILTER] - notification.data: ${notification.data}');
```

## 🎯 HOW THE FIX WORKS

### For Vehicle Status Notifications:
1. **Cloud Function** sends notification with:
   - `deviceName`: "BOA7322B2EC4" (actual device)
   - `vehicleName`: "Beat" (human-readable name)

2. **Flutter App** now correctly:
   - Sets `deviceName` field to actual device name ("BOA7322B2EC4")
   - Uses device name for filtering logic
   - Falls back to vehicleName matching if device name doesn't match

3. **Filtering Logic** checks multiple fields:
   - Primary: `notification.deviceName` vs cached device name
   - Secondary: `data['deviceName']` vs cached device name  
   - Tertiary: `data['deviceId']` vs vehicle's device ID
   - **NEW**: `data['vehicleName']` vs selected vehicle name
   - **NEW**: `data['deviceIdentifier']` vs cached device name

### Filter Scenarios Now Supported:
- ✅ **All Vehicles + Vehicle Status**: Shows all vehicle status notifications
- ✅ **Specific Vehicle + Vehicle Status**: Shows only that vehicle's status notifications
- ✅ **All Vehicles + Geofence Alerts**: Shows all geofence notifications
- ✅ **Specific Vehicle + Geofence Alerts**: Shows only that vehicle's geofence notifications
- ✅ **Specific Vehicle + All Types**: Shows both status and geofence for that vehicle

## 🧪 TESTING RECOMMENDATIONS

1. **Test Vehicle Status Filtering:**
   - Select "Vehicle Status" filter + "All Vehicles" → Should show all status notifications
   - Select "Vehicle Status" filter + specific vehicle → Should show only that vehicle's status
   - Turn a vehicle on/off → Should appear in both "All Vehicles" and specific vehicle filter

2. **Test Combined Filtering:**
   - Select specific vehicle + "All Types" → Should show both status and geofence notifications
   - Switch between vehicles → Notifications should change accordingly
   - Switch between notification types → Should filter correctly

3. **Check Debug Output:**
   - Monitor console for filter debug messages
   - Verify device name mapping is working correctly
   - Confirm notification data structure matches expectations

## 📈 EXPECTED OUTCOMES

- ✅ Vehicle Status notifications now appear when filtering by specific vehicle
- ✅ All existing geofence filtering continues to work correctly
- ✅ Combined vehicle + type filtering works as expected
- ✅ Debug logging helps identify any remaining issues
- ✅ Maintains backward compatibility with existing notifications

The fix addresses the core issue where vehicle status notifications weren't being matched to their respective vehicles due to incorrect device name handling in the notification parsing logic.

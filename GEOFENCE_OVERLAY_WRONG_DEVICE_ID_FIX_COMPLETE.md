# Geofence Overlay Wrong Device ID Fix - COMPLETE

## Critical Issue Identified
The geofence overlay was loading geofences from the **wrong device** when users switched vehicles and then toggled the overlay.

### Root Cause Analysis
Based on the debug logs:
- **Current Device ID**: `6825DDF1CB08` (correct device for GPS)
- **Geofences Loaded**: From device `lEMiw4xBiM6pxZuNXwi3` (WRONG device!)

**The Problem:**
1. User switches from Vehicle A to Vehicle B
2. `currentDeviceId` gets updated for GPS (correct)
3. User toggles geofence overlay
4. `_toggleGeofenceOverlay()` calls `_loadGeofenceOverlayData()`
5. `_loadGeofenceOverlayData()` uses `widget.deviceId` (Vehicle A's ID - WRONG!)
6. Result: Vehicle B shows Vehicle A's geofences

**Why This Happened:**
- `widget.deviceId` is set when the widget is created and **never changes**
- When switching vehicles, only `currentDeviceId` (for GPS) was updated
- Geofence loading continued using the original `widget.deviceId`

## Fix Applied

### 1. Added Current Vehicle ID Tracking
**New State Variable:**
```dart
String? currentVehicleId; // Track current vehicle ID for geofences
```

**Purpose:**
- Separate tracking for geofence queries vs GPS queries
- Updates when vehicles are switched
- Used consistently for all geofence operations

### 2. Updated Initialization Logic
**Widget Initialization:**
```dart
setState(() {
  currentDeviceId = deviceName ?? widget.deviceId; // For GPS
  currentVehicleId = widget.deviceId; // For geofences
});
```

**Fallback Logic:**
```dart
setState(() {
  currentDeviceId = widget.deviceId; // For GPS fallback
  currentVehicleId = widget.deviceId; // For geofences fallback
});
```

### 3. Updated Vehicle Switching Logic
**In `_switchToVehicle()`:**
```dart
setState(() {
  // ...existing code...
  currentVehicleId = vehicleId; // Update current vehicle ID for geofences
});
```

**Impact:**
- `currentVehicleId` now correctly tracks the active vehicle
- Geofence queries use the correct vehicle ID after switches

### 4. Fixed Overlay Toggle Logic
**Before (WRONG):**
```dart
await _loadGeofenceOverlayData(); // Uses widget.deviceId (old device)
```

**After (CORRECT):**
```dart
await _loadGeofenceOverlayDataForVehicle(currentVehicleId ?? widget.deviceId); // Uses current vehicle
```

**Impact:**
- Overlay toggle now loads geofences for the **current** vehicle
- No more cross-contamination between devices

### 5. Enhanced Debug Logging
**Added comprehensive vehicle ID tracking:**
```dart
📥 [MAP_OVERLAY_SIMPLE] Current device ID (for GPS): 6825DDF1CB08
📥 [MAP_OVERLAY_SIMPLE] Vehicle ID (for geofences): 6825DDF1CB08  
📥 [MAP_OVERLAY_SIMPLE] Current tracked vehicle ID: 6825DDF1CB08
```

**Impact:**
- Clear visibility into which IDs are being used
- Easy detection of ID mismatches
- Confirmation that the correct vehicle is being queried

## Expected Behavior (Fixed)

### Device Switching + Overlay Toggle:
1. **Start**: Vehicle A, overlay shows A's geofences
2. **Switch to Vehicle B**: GPS switches to B, overlay clears
3. **Toggle overlay on Vehicle B**: Shows **B's geofences** (not A's!)
4. **Switch to Vehicle C**: GPS switches to C, overlay clears  
5. **Toggle overlay on Vehicle C**: Shows **C's geofences** (not A's or B's!)

### Debug Log Flow (Fixed):
```
🔄 Vehicle switch from deviceA to vehicleB
📥 [MAP_OVERLAY_SIMPLE] Current tracked vehicle ID: vehicleB
📥 [MAP_OVERLAY_SIMPLE] Loading geofence data for vehicle: vehicleB
📦 [OVERLAY_SIMPLE] Received X docs from Firestore (for vehicleB)
🗺️ Rendering geofence: ... (Device: vehicleB)
```

## Files Modified
1. **`lib/screens/Maps/mapView.dart`**:
   - Added `currentVehicleId` state variable
   - Updated initialization to set both device IDs
   - Updated vehicle switching to update `currentVehicleId`
   - Fixed overlay toggle to use current vehicle ID
   - Enhanced debug logging for vehicle ID tracking

## Testing Impact
This fix resolves the critical bug where:
- ❌ **Before**: Vehicle B showed Vehicle A's geofences
- ✅ **After**: Vehicle B shows only Vehicle B's geofences

The geofence overlay now maintains **complete device isolation** and **accurate data display** regardless of vehicle switching patterns.

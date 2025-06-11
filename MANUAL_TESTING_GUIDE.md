# Manual Testing Guide for GPS App Fixes

## Overview

This guide will help you manually test the two critical fixes implemented:

1. **Cascade Delete Fix** - Devices deletion now properly cleans up vehicle references
2. **Device Assignment Fix** - Dropdown selection behavior corrected

## Pre-Testing Setup

1. Ensure you have test data in Firebase:
   - At least 2-3 devices
   - At least 2-3 vehicles
   - Some vehicles should be assigned to devices

## Test Case 1: Cascade Delete Fix

### Objective

Verify that deleting a device automatically nullifies the deviceId field in all vehicles that were assigned to that device.

### Steps

1. **Setup Phase:**

   - Navigate to Vehicle Management screen
   - Note which vehicles are currently assigned to devices
   - Identify a device that has vehicles assigned to it
   - Record the vehicle names for verification

2. **Delete Device:**

   - Navigate to Device Management screen
   - Find the device that has vehicles assigned
   - Delete this device
   - Confirm deletion

3. **Verification:**
   - Navigate back to Vehicle Management screen
   - Check the vehicles that were previously assigned to the deleted device
   - **EXPECTED RESULT:** These vehicles should now show "No device assigned" or similar
   - **FAILURE SIGNS:** App crashes, vehicles still show deleted device name, or assertion errors

### Expected Behavior

- ✅ Device deletion completes successfully
- ✅ No crashes or assertion errors
- ✅ Previously assigned vehicles now show no device assignment
- ✅ Other vehicles remain unaffected

## Test Case 2: Device Assignment Fix

### Objective

Verify that device selection in dropdown doesn't immediately assign the device, but waits for the update button press.

### Steps

1. **Setup Phase:**

   - Navigate to Vehicle Management screen
   - Select a vehicle that currently has no device assigned
   - Click "Edit" or "Manage" for this vehicle

2. **Test Dropdown Behavior:**

   - Open the device assignment dropdown
   - Select a device from the dropdown
   - **DO NOT PRESS UPDATE YET**
   - Check if the assignment has already happened (look for immediate UI changes)

3. **Cancel Test:**

   - Without pressing update, navigate away or cancel the edit
   - Return to vehicle list
   - **EXPECTED RESULT:** Vehicle should still have no device assigned

4. **Proper Assignment Test:**
   - Edit the same vehicle again
   - Select a device from dropdown
   - This time, press the "Update" button
   - **EXPECTED RESULT:** Vehicle should now be assigned to the selected device

### Expected Behavior

- ✅ Dropdown selection doesn't immediately assign device
- ✅ Assignment only happens when update button is pressed
- ✅ Canceling edit reverts any dropdown selections
- ✅ No crashes or assertion errors in dropdown

## Test Case 3: Edge Cases

### Test Multiple Vehicles with Same Device

1. Assign multiple vehicles to the same device
2. Delete that device
3. Verify all vehicles are unassigned

### Test Device Reassignment

1. Take a vehicle assigned to Device A
2. Change assignment to Device B
3. Verify Device A becomes available for other vehicles
4. Verify Device B is no longer available for other vehicles

### Test Dropdown Filtering

1. Edit Vehicle A (assigned to Device X)
2. Open dropdown for Vehicle B
3. **EXPECTED:** Device X should be disabled/filtered out
4. Cancel Vehicle B edit
5. Edit Vehicle A and change to Device Y
6. Edit Vehicle B again
7. **EXPECTED:** Device X should now be available, Device Y should be filtered out

## Troubleshooting

### If Cascade Delete Fails

- Check Firebase console for orphaned vehicle records
- Look for console errors mentioning "deviceId" or "assertion"
- Verify the batch operation logs

### If Device Assignment Fails

- Check for immediate UI updates without button press
- Look for console errors in dropdown handling
- Verify current vehicle ID parameter passing

## Test Data Recommendations

Create this test scenario in Firebase:

```
Devices:
- Device1 (ID: dev1)
- Device2 (ID: dev2)
- Device3 (ID: dev3)

Vehicles:
- Vehicle1 (deviceId: dev1)
- Vehicle2 (deviceId: dev1)
- Vehicle3 (deviceId: dev2)
- Vehicle4 (deviceId: null)
```

This setup allows testing:

- Multiple vehicles per device (Vehicle1, Vehicle2 → Device1)
- Single vehicle per device (Vehicle3 → Device2)
- Unassigned vehicle (Vehicle4)

## Success Criteria

✅ All devices can be deleted without crashes
✅ Vehicle references are automatically cleaned up
✅ Dropdown selections don't immediately assign
✅ Update button properly saves assignments
✅ No assertion errors in any scenario
✅ UI remains responsive throughout testing

## Failure Indicators

❌ App crashes during device deletion
❌ Vehicles still reference deleted devices
❌ Immediate assignment on dropdown selection
❌ Assertion failed errors in console
❌ UI freezes or becomes unresponsive

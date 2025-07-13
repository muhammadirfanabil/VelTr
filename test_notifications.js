#!/usr/bin/env node

/**
 * Test script for Vehicle Status and Geofence FCM Notifications
 * This script tests both notification types to ensure they appear on phones
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin (make sure to set your service account key)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    // or use: credential: admin.credential.cert(require('./path-to-service-account-key.json'))
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

async function testVehicleStatusNotification(userId, deviceId = "TEST_DEVICE") {
  console.log("🧪 Testing Vehicle Status Notification...");

  try {
    // Get user's FCM tokens
    const userDoc = await db.collection("users_information").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      throw new Error("No FCM tokens found for user");
    }

    // Test vehicle status notification
    const relayStatus = true; // Testing "ON" status
    const title = "Vehicle Status Update";
    const body = `Test Vehicle (${deviceId}) has been successfully turned on.`;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "vehicle_status",
        deviceId: deviceId,
        deviceName: deviceId,
        vehicleName: "Test Vehicle",
        relayStatus: "true",
        statusText: "on",
        actionText: "turned on",
        timestamp: new Date().toISOString(),
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          icon: "ic_notification",
          color: "#4CAF50", // Green for ON
          channelId: "vehicle_status_channel",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      token: fcmTokens[0], // Send to first token
    };

    const response = await messaging.send(message);
    console.log("✅ Vehicle Status Notification sent successfully:", response);

    // Store in database
    await db.collection("notifications").add({
      ownerId: userId,
      deviceId: deviceId,
      deviceIdentifier: deviceId,
      deviceName: deviceId,
      vehicleName: "Test Vehicle",
      relayStatus: true,
      statusText: "on",
      actionText: "turned on",
      message: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date(),
      read: false,
      sentToTokens: 1,
      totalTokens: fcmTokens.length,
      type: "vehicle_status",
    });

    console.log("✅ Vehicle Status Notification stored in database");
    return true;
  } catch (error) {
    console.error("❌ Vehicle Status Notification failed:", error);
    return false;
  }
}

async function testGeofenceNotification(userId, deviceId = "TEST_DEVICE") {
  console.log("🧪 Testing Geofence Notification...");

  try {
    // Get user's FCM tokens
    const userDoc = await db.collection("users_information").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      throw new Error("No FCM tokens found for user");
    }

    // Test geofence notification
    const title = "Geofence Alert";
    const body = `${deviceId} has entered Test Geofence`;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "geofence_alert",
        deviceId: deviceId,
        deviceName: deviceId,
        geofenceName: "Test Geofence",
        action: "enter",
        latitude: "-6.2088",
        longitude: "106.8456",
        timestamp: new Date().toISOString(),
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          icon: "ic_notification",
          color: "#2196F3", // Blue for ENTER
          channelId: "geofence_alerts_channel",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      token: fcmTokens[0], // Send to first token
    };

    const response = await messaging.send(message);
    console.log("✅ Geofence Notification sent successfully:", response);

    // Store in database
    await db.collection("notifications").add({
      ownerId: userId,
      deviceId: deviceId,
      deviceIdentifier: deviceId,
      deviceName: deviceId,
      geofenceName: "Test Geofence",
      action: "enter",
      message: body,
      location: {
        latitude: -6.2088,
        longitude: 106.8456,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date(),
      read: false,
      sentToTokens: 1,
      totalTokens: fcmTokens.length,
      type: "geofence_alert",
    });

    console.log("✅ Geofence Notification stored in database");
    return true;
  } catch (error) {
    console.error("❌ Geofence Notification failed:", error);
    return false;
  }
}

// Main test function
async function runTests() {
  const userId = process.argv[2];
  const deviceId = process.argv[3] || "TEST_DEVICE";

  if (!userId) {
    console.error("❌ Usage: node test_notifications.js <userId> [deviceId]");
    console.error("   Example: node test_notifications.js abc123def456");
    process.exit(1);
  }

  console.log(`🚀 Testing FCM Notifications for user: ${userId}`);
  console.log(`📱 Device ID: ${deviceId}`);
  console.log("=".repeat(60));

  try {
    // Test vehicle status notification
    const vehicleResult = await testVehicleStatusNotification(userId, deviceId);

    // Wait 3 seconds between tests
    console.log("⏳ Waiting 3 seconds before next test...");
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Test geofence notification
    const geofenceResult = await testGeofenceNotification(userId, deviceId);

    console.log("=".repeat(60));
    console.log("📊 TEST RESULTS:");
    console.log(`✅ Vehicle Status: ${vehicleResult ? "PASSED" : "FAILED"}`);
    console.log(`✅ Geofence Alert: ${geofenceResult ? "PASSED" : "FAILED"}`);

    if (vehicleResult && geofenceResult) {
      console.log("🎉 All tests passed! Check your phone for notifications.");
    } else {
      console.log("⚠️  Some tests failed. Check the error messages above.");
    }
  } catch (error) {
    console.error("❌ Test execution failed:", error);
    process.exit(1);
  }
}

// Run the tests
runTests()
  .then(() => {
    console.log("✅ Test script completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Test script failed:", error);
    process.exit(1);
  });

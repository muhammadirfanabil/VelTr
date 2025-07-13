#!/usr/bin/env node

/**
 * FCM Token Debug Script
 * This script helps debug FCM token issues and test notifications
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL:
      "https://gps-project-a5c9a-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Check user's FCM tokens and their validity
 * @param {string} userId - User ID to check
 */
async function debugUserFCMTokens(userId) {
  console.log(`🔍 Debugging FCM tokens for user: ${userId}`);
  console.log("=".repeat(60));

  try {
    // Get user document
    const userDoc = await db.collection("users_information").doc(userId).get();

    if (!userDoc.exists) {
      console.log("❌ User not found in users_information collection");
      return null;
    }

    const userData = userDoc.data();
    console.log("✅ User found");
    console.log(`📧 Email: ${userData.email || "N/A"}`);
    console.log(`👤 Name: ${userData.name || "N/A"}`);
    console.log(
      `📱 FCM Tokens: ${userData.fcmTokens ? userData.fcmTokens.length : 0}`
    );

    if (!userData.fcmTokens || userData.fcmTokens.length === 0) {
      console.log("⚠️  No FCM tokens found for this user");
      console.log(
        "💡 Make sure the user has logged into the app and FCM tokens are properly stored"
      );
      return null;
    }

    console.log("\n🔑 FCM Tokens:");
    const validTokens = [];
    const invalidTokens = [];

    for (let i = 0; i < userData.fcmTokens.length; i++) {
      const token = userData.fcmTokens[i];
      console.log(`\n📱 Token ${i + 1}:`);
      console.log(
        `   Preview: ${token.substring(0, 20)}...${token.substring(
          token.length - 10
        )}`
      );
      console.log(`   Length: ${token.length} characters`);

      // Test token validity by sending a dry run
      try {
        await messaging.send(
          {
            token: token,
            data: { test: "dry_run" },
          },
          true
        ); // dry run = true

        console.log("   ✅ Token is VALID");
        validTokens.push(token);
      } catch (error) {
        console.log(`   ❌ Token is INVALID: ${error.code}`);
        invalidTokens.push(token);
      }
    }

    console.log(`\n📊 Token Summary:`);
    console.log(`   Valid tokens: ${validTokens.length}`);
    console.log(`   Invalid tokens: ${invalidTokens.length}`);

    return {
      userId,
      validTokens,
      invalidTokens,
      userData,
    };
  } catch (error) {
    console.error("❌ Error checking FCM tokens:", error);
    return null;
  }
}

/**
 * Send a test vehicle status notification
 * @param {string} userId - User ID
 * @param {string} action - "on" or "off"
 */
async function sendTestVehicleStatusNotification(userId, action = "on") {
  console.log(`\n🧪 Sending test vehicle status notification...`);
  console.log(`👤 User: ${userId}`);
  console.log(`🔌 Action: ${action}`);

  try {
    const tokenInfo = await debugUserFCMTokens(userId);
    if (!tokenInfo || tokenInfo.validTokens.length === 0) {
      console.log("❌ Cannot send notification - no valid tokens");
      return false;
    }

    const relayStatus = action === "on";
    const statusText = relayStatus ? "on" : "off";
    const actionText = relayStatus ? "turned on" : "turned off";
    const title = "🧪 Test Vehicle Status Update";
    const body = `Test Vehicle has been successfully ${actionText}.`;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "vehicle_status",
        deviceId: "TEST_DEVICE_DEBUG",
        deviceName: "Test Vehicle",
        vehicleName: "Test Vehicle",
        relayStatus: relayStatus.toString(),
        statusText: statusText,
        actionText: actionText,
        timestamp: new Date().toISOString(),
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          icon: "ic_notification",
          color: relayStatus ? "#4CAF50" : "#F44336", // Green for ON, Red for OFF
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
    };

    // Send to the first valid token
    const testToken = tokenInfo.validTokens[0];
    console.log(`📤 Sending to token: ${testToken.substring(0, 20)}...`);

    const response = await messaging.send({
      ...message,
      token: testToken,
    });

    console.log("✅ Vehicle status notification sent successfully!");
    console.log(`📬 FCM Response: ${response}`);

    // Store in database
    const notificationData = {
      ownerId: userId,
      deviceId: "TEST_DEVICE_DEBUG",
      deviceIdentifier: "TEST_DEVICE_DEBUG",
      deviceName: "Test Vehicle",
      vehicleName: "Test Vehicle",
      relayStatus: relayStatus,
      statusText: statusText,
      actionText: actionText,
      message: body,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date(),
      read: false,
      sentToTokens: 1,
      totalTokens: tokenInfo.validTokens.length,
      type: "vehicle_status",
      testMessage: true,
    };

    const notificationRef = await db
      .collection("notifications")
      .add(notificationData);
    console.log(`📝 Notification logged to database: ${notificationRef.id}`);

    return true;
  } catch (error) {
    console.error("❌ Error sending test notification:", error);
    return false;
  }
}

/**
 * Send a test geofence notification
 * @param {string} userId - User ID
 * @param {string} action - "enter" or "exit"
 */
async function sendTestGeofenceNotification(userId, action = "enter") {
  console.log(`\n🧪 Sending test geofence notification...`);
  console.log(`👤 User: ${userId}`);
  console.log(`🚪 Action: ${action}`);

  try {
    const tokenInfo = await debugUserFCMTokens(userId);
    if (!tokenInfo || tokenInfo.validTokens.length === 0) {
      console.log("❌ Cannot send notification - no valid tokens");
      return false;
    }

    const actionText = action === "enter" ? "entered" : "exited";
    const title = "🧪 Test Geofence Alert";
    const body = `Test Vehicle has ${actionText} Test Geofence`;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "geofence_alert",
        deviceId: "TEST_DEVICE_DEBUG",
        deviceName: "Test Vehicle",
        geofenceName: "Test Geofence",
        action: action,
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
          color: action === "enter" ? "#2196F3" : "#FF9800", // Blue for ENTER, Orange for EXIT
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
    };

    // Send to the first valid token
    const testToken = tokenInfo.validTokens[0];
    console.log(`📤 Sending to token: ${testToken.substring(0, 20)}...`);

    const response = await messaging.send({
      ...message,
      token: testToken,
    });

    console.log("✅ Geofence notification sent successfully!");
    console.log(`📬 FCM Response: ${response}`);

    // Store in database
    const notificationData = {
      ownerId: userId,
      deviceId: "TEST_DEVICE_DEBUG",
      deviceIdentifier: "TEST_DEVICE_DEBUG",
      deviceName: "Test Vehicle",
      geofenceName: "Test Geofence",
      action: action,
      message: body,
      location: {
        latitude: -6.2088,
        longitude: 106.8456,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date(),
      read: false,
      sentToTokens: 1,
      totalTokens: tokenInfo.validTokens.length,
      type: "geofence_alert",
      testMessage: true,
    };

    const notificationRef = await db
      .collection("notifications")
      .add(notificationData);
    console.log(`📝 Notification logged to database: ${notificationRef.id}`);

    return true;
  } catch (error) {
    console.error("❌ Error sending test notification:", error);
    return false;
  }
}

/**
 * Main function to run all tests
 */
async function runDebugSession() {
  const TEST_USER_ID = process.argv[2]; // Get user ID from command line argument

  if (!TEST_USER_ID) {
    console.log("❌ Please provide a user ID as argument");
    console.log("💡 Usage: node debug_fcm_tokens.js <USER_ID>");
    console.log(
      "🔍 You can find user IDs in Firebase Console > Firestore > users_information collection"
    );
    return;
  }

  console.log("🧪 FCM TOKENS DEBUG SESSION");
  console.log("=".repeat(60));
  console.log(`⏰ Started at: ${new Date().toISOString()}`);

  try {
    // 1. Debug FCM tokens
    const tokenInfo = await debugUserFCMTokens(TEST_USER_ID);

    if (!tokenInfo || tokenInfo.validTokens.length === 0) {
      console.log(
        "\n❌ Cannot proceed with notification tests - no valid tokens"
      );
      return;
    }

    // 2. Test vehicle status notifications
    console.log("\n" + "=".repeat(60));
    console.log("🚗 TESTING VEHICLE STATUS NOTIFICATIONS");
    console.log("=".repeat(60));

    await sendTestVehicleStatusNotification(TEST_USER_ID, "on");
    await new Promise((resolve) => setTimeout(resolve, 3000)); // Wait 3 seconds
    await sendTestVehicleStatusNotification(TEST_USER_ID, "off");

    // 3. Test geofence notifications
    console.log("\n" + "=".repeat(60));
    console.log("🎯 TESTING GEOFENCE NOTIFICATIONS");
    console.log("=".repeat(60));

    await new Promise((resolve) => setTimeout(resolve, 3000)); // Wait 3 seconds
    await sendTestGeofenceNotification(TEST_USER_ID, "enter");
    await new Promise((resolve) => setTimeout(resolve, 3000)); // Wait 3 seconds
    await sendTestGeofenceNotification(TEST_USER_ID, "exit");

    console.log("\n" + "=".repeat(60));
    console.log("✅ DEBUG SESSION COMPLETED SUCCESSFULLY!");
    console.log("📱 Check your phone for the test notifications");
    console.log(
      "🔍 Check Firebase Console > Firestore > notifications collection for logs"
    );
    console.log("=".repeat(60));
  } catch (error) {
    console.error("\n❌ Debug session failed:", error);
  }
}

// Export functions for use in other scripts
module.exports = {
  debugUserFCMTokens,
  sendTestVehicleStatusNotification,
  sendTestGeofenceNotification,
};

// Run the debug session if this script is called directly
if (require.main === module) {
  runDebugSession();
}

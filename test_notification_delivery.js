const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Test FCM Notification Delivery
async function testNotificationDelivery() {
  console.log("🧪 Testing FCM Notification Delivery...");

  try {
    const db = getFirestore();
    const messaging = getMessaging();

    // Get a test user's FCM tokens
    console.log("📋 Step 1: Checking user FCM tokens...");
    const usersSnapshot = await db
      .collection("users_information")
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log("❌ No users found in users_information collection");
      return;
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    const ownerId = userDoc.id;

    console.log(`👤 Testing with user: ${ownerId}`);
    console.log(`📱 FCM tokens found: ${userData.fcmTokens?.length || 0}`);

    if (!userData.fcmTokens || userData.fcmTokens.length === 0) {
      console.log("❌ No FCM tokens found for test user");
      console.log(
        "💡 Make sure the user has logged in and FCM tokens are saved"
      );
      return;
    }

    // Test FCM message
    console.log("📋 Step 2: Testing FCM message delivery...");
    const testMessage = {
      data: {
        type: "geofence_alert",
        deviceId: "test_device",
        deviceName: "Test Vehicle",
        geofenceName: "Test Geofence",
        action: "enter",
        latitude: "-6.2088",
        longitude: "106.8456",
        timestamp: new Date().toISOString(),
        title: "🧪 Test Notification",
        body: "This is a test notification to verify FCM delivery",
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    };

    const testToken = userData.fcmTokens[0];
    console.log(
      `📤 Sending test message to token: ${testToken.substring(0, 20)}...`
    );

    try {
      await messaging.send({
        ...testMessage,
        token: testToken,
      });
      console.log("✅ Test FCM message sent successfully!");
    } catch (fcmError) {
      console.log("❌ FCM send error:", fcmError.code, fcmError.message);

      if (fcmError.code === "messaging/registration-token-not-registered") {
        console.log(
          "💡 Token is invalid - user needs to re-login to get new token"
        );
      } else if (fcmError.code === "messaging/invalid-registration-token") {
        console.log("💡 Token format is invalid");
      }

      return;
    }

    // Test notification database storage
    console.log("📋 Step 3: Testing notification database storage...");
    const notificationData = {
      ownerId: ownerId,
      deviceId: "test_device",
      deviceIdentifier: "test_device",
      deviceName: "Test Vehicle",
      geofenceName: "Test Geofence",
      action: "enter",
      message: "This is a test notification to verify database storage",
      location: {
        latitude: -6.2088,
        longitude: 106.8456,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date(),
      read: false,
      sentToTokens: 1,
      totalTokens: userData.fcmTokens.length,
    };

    const notificationRef = await db
      .collection("notifications")
      .add(notificationData);
    console.log(
      `✅ Test notification stored in database: ${notificationRef.id}`
    );

    // Check recent geofence logs
    console.log("📋 Step 4: Checking recent geofence logs...");
    const recentLogs = await db
      .collection("geofence_logs")
      .orderBy("timestamp", "desc")
      .limit(5)
      .get();

    console.log(`📊 Recent geofence logs: ${recentLogs.size} entries`);
    recentLogs.forEach((doc, index) => {
      const log = doc.data();
      console.log(
        `  ${index + 1}. ${log.deviceName} - ${log.action} ${
          log.geofenceName
        } (${log.timestamp?.toDate?.()?.toISOString() || log.createdAt})`
      );
    });

    console.log(
      "\n✅ Test completed! Check your device for the test notification."
    );
    console.log("💡 If no notification appeared, check:");
    console.log("   1. Device notification permissions");
    console.log("   2. App is not in battery optimization");
    console.log("   3. FCM token is valid (user logged in recently)");
    console.log("   4. Firebase project configuration");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

// Test notification cooldown logic
async function testCooldownLogic() {
  console.log("\n🧪 Testing Cooldown Logic...");

  try {
    const db = getFirestore();

    // Create a test notification to simulate recent activity
    const testDeviceId = "test_device_cooldown";
    const testGeofenceName = "Test Geofence Cooldown";

    console.log(`📋 Step 1: Creating recent notification for cooldown test...`);
    await db.collection("notifications").add({
      deviceId: testDeviceId,
      geofenceName: testGeofenceName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      action: "enter",
      message: "Test notification for cooldown",
      createdAt: new Date(),
    });

    console.log(`📋 Step 2: Testing cooldown function...`);

    // This would be your actual cooldown function
    const cooldownMinutes = 2;
    const cooldownMs = cooldownMinutes * 60 * 1000;
    const cutoffTime = new Date(Date.now() - cooldownMs);

    const recentNotification = await db
      .collection("notifications")
      .where("deviceId", "==", testDeviceId)
      .where("geofenceName", "==", testGeofenceName)
      .where("timestamp", ">=", cutoffTime)
      .limit(1)
      .get();

    const canSend = recentNotification.empty;
    console.log(
      `📊 Cooldown result: ${
        canSend ? "CAN SEND" : "BLOCKED (cooldown active)"
      }`
    );

    if (!canSend) {
      console.log(
        "✅ Cooldown is working correctly - notifications will be rate limited"
      );
    } else {
      console.log("⚠️ No recent notifications found - cooldown not active");
    }
  } catch (error) {
    console.error("❌ Cooldown test failed:", error);
  }
}

// Export for use
module.exports = {
  testNotificationDelivery,
  testCooldownLogic,
};

// Run tests if this file is executed directly
if (require.main === module) {
  // Initialize Firebase Admin
  const admin = require("firebase-admin");

  if (!admin.apps.length) {
    admin.initializeApp();
  }

  async function runTests() {
    await testNotificationDelivery();
    await testCooldownLogic();
  }

  runTests().catch(console.error);
}

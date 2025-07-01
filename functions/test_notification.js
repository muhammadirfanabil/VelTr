const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = getFirestore();
const messaging = getMessaging();

// Test FCM Notification Delivery
async function testNotificationDelivery() {
  console.log("🧪 Testing FCM Notification Delivery...");

  try {
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

// Run the test
testNotificationDelivery().catch(console.error);

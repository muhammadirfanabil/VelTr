#!/usr/bin/env node

/**
 * Simple test script to verify Vehicle Status Notifications
 * This script calls the deployed Cloud Function to test FCM notifications
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: "https://gps-project-a5c9a-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const functions = admin.functions();

async function testVehicleStatusNotification(userId, action = "on") {
  console.log(`🧪 Testing Vehicle Status Notification for user: ${userId}`);
  console.log(`📱 Action: ${action}`);
  
  try {
    // Call the deployed Cloud Function
    const callable = functions.httpsCallable('testvehiclestatusnotification');
    
    const result = await callable({
      deviceId: "TEST_DEVICE_001",
      action: action
    });

    console.log("✅ Test Result:", result.data);
    return result.data;
  } catch (error) {
    console.error("❌ Test Failed:", error.message);
    throw error;
  }
}

async function runTest() {
  // You need to replace this with a real user ID from your database
  const TEST_USER_ID = "YOUR_USER_ID_HERE"; // Replace with actual user ID
  
  if (TEST_USER_ID === "YOUR_USER_ID_HERE") {
    console.log("⚠️  Please update TEST_USER_ID with a real user ID from your database");
    console.log("🔍 You can find user IDs in Firebase Console > Firestore > users_information collection");
    return;
  }

  try {
    console.log("🚀 Starting Vehicle Status Notification Test...");
    console.log("=" .repeat(50));

    // Test "ON" notification
    console.log("\n📱 Testing 'ON' notification...");
    await testVehicleStatusNotification(TEST_USER_ID, "on");
    
    // Wait a bit before next test
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test "OFF" notification
    console.log("\n📱 Testing 'OFF' notification...");
    await testVehicleStatusNotification(TEST_USER_ID, "off");

    console.log("\n" + "=".repeat(50));
    console.log("✅ All tests completed successfully!");
    console.log("📱 Check your phone for the notifications");
    
  } catch (error) {
    console.error("\n❌ Test failed:", error.message);
  }
}

// Run the test
if (require.main === module) {
  runTest();
}

module.exports = { testVehicleStatusNotification };

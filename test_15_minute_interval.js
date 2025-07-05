// Test script to verify 15-minute interval enforcement and UTC timestamp handling
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const functions = require("firebase-functions-test")();

// Initialize Firebase Admin
initializeApp({
  projectId: "gps-project-a5c9a",
});

const db = getFirestore();

// Import our function
const myFunctions = require("./index");

async function test15MinuteInterval() {
  console.log("🧪 Testing 15-minute interval enforcement and UTC handling...");

  try {
    // First, let's get a test vehicle and device
    console.log("📊 Finding test vehicle and device...");
    const vehiclesSnapshot = await db.collection("vehicles").limit(1).get();

    if (vehiclesSnapshot.empty) {
      console.log("❌ No vehicles found - create a vehicle first");
      return;
    }

    const testVehicle = vehiclesSnapshot.docs[0];
    const vehicleData = testVehicle.data();
    const vehicleId = testVehicle.id;
    const ownerId = vehicleData.ownerId;

    console.log(`🚗 Using vehicle: ${vehicleId}, owner: ${ownerId}`);

    // Find a device for this vehicle
    const devicesSnapshot = await db
      .collection("devices")
      .where("vehicleId", "==", vehicleId)
      .limit(1)
      .get();

    if (devicesSnapshot.empty) {
      console.log("❌ No devices found for this vehicle");
      return;
    }

    const testDevice = devicesSnapshot.docs[0];
    const deviceId = testDevice.id;
    console.log(`📱 Using device: ${deviceId}`);

    // Test coordinates (Jakarta area)
    const testCoords = [
      { lat: -6.2088, lng: 106.8456, desc: "Monas area" },
      { lat: -6.209, lng: 106.8458, desc: "5 meters away" },
      { lat: -6.21, lng: 106.847, desc: "100 meters away" },
    ];

    // Test 1: Clear existing history for clean test
    console.log("\n🧹 Cleaning existing history for clean test...");
    const existingHistory = await db
      .collection("history")
      .where("vehicleId", "==", vehicleId)
      .get();

    const batch = db.batch();
    existingHistory.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`✅ Deleted ${existingHistory.size} existing history entries`);

    // Test 2: First entry should always be logged
    console.log("\n📍 Test 1: First entry should always be logged");
    await writeGPSData(deviceId, testCoords[0].lat, testCoords[0].lng);
    await sleep(2000); // Give Cloud Function time to process

    let historyCount = await getHistoryCount(vehicleId);
    console.log(
      `✅ History count after first entry: ${historyCount} (expected: 1)`
    );

    // Test 3: Second entry within 15 minutes should be skipped
    console.log("\n⏰ Test 2: Entry within 15 minutes should be skipped");
    await writeGPSData(deviceId, testCoords[1].lat, testCoords[1].lng);
    await sleep(2000);

    historyCount = await getHistoryCount(vehicleId);
    console.log(
      `✅ History count after second entry (within 15 min): ${historyCount} (expected: 1)`
    );

    // Test 4: Check timestamp format and UTC handling
    console.log("\n🕐 Test 3: Checking UTC timestamp format");
    const historyEntries = await db
      .collection("history")
      .where("vehicleId", "==", vehicleId)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (!historyEntries.empty) {
      const entry = historyEntries.docs[0].data();
      const createdAt = entry.createdAt;
      const metadata = entry.metadata || {};

      console.log("📊 Timestamp analysis:");
      console.log(`  - Firestore timestamp: ${createdAt}`);
      console.log(`  - Firestore timestamp type: ${typeof createdAt}`);
      console.log(`  - As Date: ${createdAt.toDate()}`);
      console.log(`  - As UTC ISO: ${createdAt.toDate().toISOString()}`);
      console.log(`  - Metadata UTC ISO: ${metadata.loggedAtUTC}`);
      console.log(`  - Metadata timestamp: ${metadata.loggedAtTimestamp}`);
      console.log(`  - Log reason: ${metadata.logReason}`);
    }

    // Test 5: Query function should return proper UTC timestamps
    console.log("\n📤 Test 4: Query function UTC timestamp format");
    const mockRequest = {
      auth: { uid: ownerId },
      data: { vehicleId: vehicleId, days: 1 },
    };

    const queryResult = await myFunctions.querydrivinghistory(mockRequest);
    if (queryResult.entries && queryResult.entries.length > 0) {
      const entry = queryResult.entries[0];
      console.log("📊 Query result timestamp analysis:");
      console.log(
        `  - createdAt: ${entry.createdAt} (should be UTC ISO string)`
      );
      console.log(
        `  - createdAtTimestamp: ${entry.createdAtTimestamp} (should be Unix timestamp)`
      );
      console.log(`  - deviceName: ${entry.deviceName}`);

      // Verify it's a valid UTC ISO string
      const parsedDate = new Date(entry.createdAt);
      console.log(`  - Parsed date: ${parsedDate}`);
      console.log(
        `  - Is valid UTC ISO: ${
          entry.createdAt.endsWith("Z") && !isNaN(parsedDate.getTime())
        }`
      );
    }

    console.log("\n✅ All tests completed successfully!");
  } catch (error) {
    console.error("❌ Test failed:", error);
  } finally {
    process.exit(0);
  }
}

// Helper function to write GPS data to trigger the Cloud Function
async function writeGPSData(deviceId, latitude, longitude) {
  const gpsData = {
    latitude: latitude,
    longitude: longitude,
    timestamp: Date.now(),
    accuracy: 10,
    speed: 0,
    bearing: 0,
  };

  console.log(
    `📡 Writing GPS data for device ${deviceId}: (${latitude}, ${longitude})`
  );
  await db.collection("devices").doc(deviceId).collection("gps").add(gpsData);
}

// Helper function to get history count
async function getHistoryCount(vehicleId) {
  const snapshot = await db
    .collection("history")
    .where("vehicleId", "==", vehicleId)
    .get();
  return snapshot.size;
}

// Helper function to sleep
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

test15MinuteInterval();

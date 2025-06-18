// Test script to directly call the querydrivinghistory function
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const functions = require("firebase-functions-test")();

// Initialize Firebase Admin
initializeApp({
  projectId: "gps-project-a5c9a",
});

const db = getFirestore();

// Import our function
const myFunctions = require("./functions/index");

async function testHistoryFunction() {
  console.log("🧪 Testing querydrivinghistory function...");

  try {
    // First, let's check if we have any vehicles in the database
    console.log("📊 Checking vehicles collection...");
    const vehiclesSnapshot = await db.collection("vehicles").limit(5).get();

    if (vehiclesSnapshot.empty) {
      console.log("❌ No vehicles found in the database");
      return;
    }

    console.log(`✅ Found ${vehiclesSnapshot.size} vehicles`);

    // Get the first vehicle for testing
    const testVehicle = vehiclesSnapshot.docs[0];
    const vehicleData = testVehicle.data();
    const vehicleId = testVehicle.id;
    const ownerId = vehicleData.ownerId;

    console.log(`🚗 Testing with vehicle: ${vehicleId}, owner: ${ownerId}`);

    // Check if there's any history for this vehicle
    console.log("📊 Checking history collection...");
    const historySnapshot = await db
      .collection("history")
      .where("vehicleId", "==", vehicleId)
      .limit(5)
      .get();

    console.log(
      `📊 Found ${historySnapshot.size} history entries for vehicle ${vehicleId}`
    );

    // Simulate a request context
    const mockRequest = {
      auth: {
        uid: ownerId,
      },
      data: {
        vehicleId: vehicleId,
        days: 7,
      },
    };

    console.log("🔍 Calling querydrivinghistory function...");
    const result = await myFunctions.querydrivinghistory(mockRequest);

    console.log("✅ Function result:", JSON.stringify(result, null, 2));
  } catch (error) {
    console.error("❌ Test failed:", error);
  } finally {
    process.exit(0);
  }
}

testHistoryFunction();

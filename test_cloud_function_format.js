const admin = require("firebase-admin");

// Initialize Firebase Admin (uses default credentials from Firebase CLI)
admin.initializeApp({
  projectId: "gps-project-a5c9a",
  databaseURL:
    "https://gps-project-a5c9a-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.firestore();

async function testCloudFunctionResponse() {
  console.log("🧪 Testing Cloud Function data format...\n");

  try {
    // Test the actual data structure in Firestore
    console.log("📋 Checking history collection structure:");
    const historySnapshot = await db.collection("history").limit(1).get();

    if (historySnapshot.empty) {
      console.log("   No history entries found");
    } else {
      historySnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Sample entry ID: ${doc.id}`);
        console.log(`   Data structure:`, JSON.stringify(data, null, 2));
        console.log(`   createdAt type: ${typeof data.createdAt}`);
        console.log(`   location type: ${typeof data.location}`);
        console.log(`   vehicleId type: ${typeof data.vehicleId}`);
        console.log(`   ownerId type: ${typeof data.ownerId}`);
      });
    }

    // Check vehicles collection
    console.log("\n📋 Checking vehicles collection:");
    const vehiclesSnapshot = await db.collection("vehicles").limit(1).get();

    if (vehiclesSnapshot.empty) {
      console.log("   No vehicles found");
    } else {
      vehiclesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Vehicle ID: ${doc.id}`);
        console.log(`   Owner ID: ${data.ownerId}`);
        console.log(`   Device ID: ${data.deviceId}`);
      });
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

testCloudFunctionResponse().then(() => {
  console.log("\n✅ Test completed");
  process.exit(0);
});

const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  const serviceAccount = require("./path/to/serviceAccountKey.json"); // Update this path
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://gps-tracker-b25f8-default-rtdb.firebaseio.com",
  });
}

const db = admin.firestore();

async function debugDeviceVehicleAssociation() {
  console.log("🔍 Debugging Device-Vehicle Association Issues...\n");

  try {
    // Get all devices
    console.log("📋 Current Devices:");
    const devicesSnapshot = await db.collection("devices").get();

    if (devicesSnapshot.empty) {
      console.log("   No devices found in Firestore");
    } else {
      devicesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Device ID: ${doc.id}`);
        console.log(`   Name: ${data.name || "N/A"}`);
        console.log(`   Owner ID: ${data.ownerId || "N/A"}`);
        console.log(`   Vehicle ID: ${data.vehicleId || "UNASSIGNED"}`);
        console.log(`   Active: ${data.isActive || false}`);
        console.log("   ---");
      });
    }

    // Get all vehicles
    console.log("\n🚗 Current Vehicles:");
    const vehiclesSnapshot = await db.collection("vehicles").get();

    if (vehiclesSnapshot.empty) {
      console.log("   No vehicles found in Firestore");
    } else {
      vehiclesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Vehicle ID: ${doc.id}`);
        console.log(`   Name: ${data.name || "N/A"}`);
        console.log(`   Owner ID: ${data.ownerId || "N/A"}`);
        console.log(`   Device ID: ${data.deviceId || "UNASSIGNED"}`);
        console.log(
          `   Created: ${
            data.createdAt
              ? new Date(data.createdAt.toDate()).toISOString()
              : "N/A"
          }`
        );
        console.log("   ---");
      });
    }

    // Check for mismatched associations
    console.log("\n⚠️  Checking for Association Mismatches:");
    let mismatches = 0;

    for (const vehicleDoc of vehiclesSnapshot.docs) {
      const vehicleData = vehicleDoc.data();
      if (vehicleData.deviceId) {
        // Check if the device exists and points back to this vehicle
        const deviceDoc = await db
          .collection("devices")
          .doc(vehicleData.deviceId)
          .get();

        if (!deviceDoc.exists) {
          console.log(
            `   ❌ Vehicle "${vehicleData.name}" (${vehicleDoc.id}) references non-existent device ${vehicleData.deviceId}`
          );
          mismatches++;
        } else {
          const deviceData = deviceDoc.data();
          if (deviceData.vehicleId !== vehicleDoc.id) {
            console.log(
              `   ❌ Vehicle "${vehicleData.name}" (${
                vehicleDoc.id
              }) references device ${
                vehicleData.deviceId
              }, but device points to vehicle ${deviceData.vehicleId || "NULL"}`
            );
            mismatches++;
          }
        }
      }
    }

    if (mismatches === 0) {
      console.log("   ✅ No association mismatches found");
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

// Run the debug function
debugDeviceVehicleAssociation()
  .then(() => {
    console.log("\n🎉 Debug complete!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Debug failed:", error);
    process.exit(1);
  });

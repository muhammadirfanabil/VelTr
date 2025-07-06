// Test script to debug device-vehicle synchronization issue
// Run this in Firebase Console to check the current state

const admin = require("firebase-admin");

if (!admin.apps.length) {
  // Initialize with your project credentials
  admin.initializeApp({
    projectId: "gps-tracker-b25f8", // Replace with your project ID
  });
}

const db = admin.firestore();

async function debugDeviceVehicleSynchronization() {
  console.log("🔍 Debugging Device-Vehicle Synchronization Issue...\n");

  try {
    // Get all vehicles
    console.log("🚗 Current Vehicles:");
    const vehiclesSnapshot = await db.collection("vehicles").get();

    if (vehiclesSnapshot.empty) {
      console.log("   No vehicles found");
    } else {
      vehiclesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Vehicle ID: ${doc.id}`);
        console.log(`   Name: ${data.name || "N/A"}`);
        console.log(`   Device ID: ${data.deviceId || "NULL"}`);
        console.log(
          `   Updated: ${
            data.updatedAt
              ? new Date(data.updatedAt.toDate()).toISOString()
              : "N/A"
          }`
        );
        console.log("   ---");
      });
    }

    // Get all devices
    console.log("\n📱 Current Devices:");
    const devicesSnapshot = await db.collection("devices").get();

    if (devicesSnapshot.empty) {
      console.log("   No devices found");
    } else {
      devicesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(`   Device ID: ${doc.id}`);
        console.log(`   Name: ${data.name || "N/A"}`);
        console.log(`   Vehicle ID: ${data.vehicleId || "NULL"}`);
        console.log(
          `   Updated: ${
            data.updatedAt
              ? new Date(data.updatedAt.toDate()).toISOString()
              : "N/A"
          }`
        );
        console.log("   ---");
      });
    }

    // Check for synchronization mismatches
    console.log("\n⚠️  Checking for Synchronization Mismatches:");
    let mismatches = 0;

    // Check vehicles pointing to devices
    for (const vehicleDoc of vehiclesSnapshot.docs) {
      const vehicleData = vehicleDoc.data();
      if (vehicleData.deviceId) {
        const deviceDoc = await db
          .collection("devices")
          .doc(vehicleData.deviceId)
          .get();

        if (!deviceDoc.exists) {
          console.log(
            `   ❌ Vehicle "${vehicleData.name}" (${vehicleDoc.id}) points to non-existent device ${vehicleData.deviceId}`
          );
          mismatches++;
        } else {
          const deviceData = deviceDoc.data();
          if (deviceData.vehicleId !== vehicleDoc.id) {
            console.log(
              `   ❌ MISMATCH: Vehicle "${vehicleData.name}" (${
                vehicleDoc.id
              }) points to device ${
                vehicleData.deviceId
              }, but device points to vehicle ${deviceData.vehicleId || "NULL"}`
            );
            mismatches++;
          }
        }
      }
    }

    // Check devices pointing to vehicles
    for (const deviceDoc of devicesSnapshot.docs) {
      const deviceData = deviceDoc.data();
      if (deviceData.vehicleId) {
        const vehicleDoc = await db
          .collection("vehicles")
          .doc(deviceData.vehicleId)
          .get();

        if (!vehicleDoc.exists) {
          console.log(
            `   ❌ Device "${deviceData.name}" (${deviceDoc.id}) points to non-existent vehicle ${deviceData.vehicleId}`
          );
          mismatches++;
        } else {
          const vehicleData = vehicleDoc.data();
          if (vehicleData.deviceId !== deviceDoc.id) {
            console.log(
              `   ❌ MISMATCH: Device "${deviceData.name}" (${
                deviceDoc.id
              }) points to vehicle ${
                deviceData.vehicleId
              }, but vehicle points to device ${vehicleData.deviceId || "NULL"}`
            );
            mismatches++;
          }
        }
      }
    }

    if (mismatches === 0) {
      console.log("   ✅ No synchronization mismatches found!");
    } else {
      console.log(`   ❌ Found ${mismatches} synchronization mismatches!`);
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

// Run the debug function
debugDeviceVehicleSynchronization()
  .then(() => {
    console.log("\n🎉 Debug complete!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Debug failed:", error);
    process.exit(1);
  });

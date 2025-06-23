const admin = require("firebase-admin");

// Initialize Firebase Admin (uses default credentials from Firebase CLI)
admin.initializeApp({
  projectId: "gps-project-a5c9a",
  databaseURL:
    "https://gps-project-a5c9a-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.firestore();

async function testDeviceMapping() {
  console.log("🔍 Testing device mapping between RTDB and Firestore...\n");

  try {
    // List all devices in Firestore
    console.log("📋 Firestore devices:");
    const devicesSnapshot = await db.collection("devices").get();

    if (devicesSnapshot.empty) {
      console.log("   No devices found in Firestore");
    } else {
      devicesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(
          `   ID: ${doc.id}, Name: ${data.name || "N/A"}, Data:`,
          data
        );
      });
    }

    console.log("\n📋 Vehicles in Firestore:");
    const vehiclesSnapshot = await db.collection("vehicles").get();

    if (vehiclesSnapshot.empty) {
      console.log("   No vehicles found in Firestore");
    } else {
      vehiclesSnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(
          `   ID: ${doc.id}, DeviceId: ${data.deviceId || "N/A"}, Data:`,
          data
        );
      });
    }

    // Test specific device lookup for DUMMY1
    console.log('\n🔍 Testing lookup for device name "DUMMY1":');
    const deviceQuery = await db
      .collection("devices")
      .where("name", "==", "DUMMY1")
      .limit(1)
      .get();

    if (deviceQuery.empty) {
      console.log('   ❌ Device "DUMMY1" not found in Firestore');

      // Try to find devices with similar names
      console.log('\n🔍 Searching for devices with names containing "DUMMY":');
      const allDevices = await db.collection("devices").get();
      const dummyDevices = [];
      allDevices.forEach((doc) => {
        const data = doc.data();
        if (data.name && data.name.includes("DUMMY")) {
          dummyDevices.push({ id: doc.id, name: data.name, data });
        }
      });

      if (dummyDevices.length > 0) {
        console.log("   Found similar devices:");
        dummyDevices.forEach((device) => {
          console.log(`     ID: ${device.id}, Name: ${device.name}`);
        });
      } else {
        console.log('   No devices found with "DUMMY" in the name');
      }
    } else {
      const deviceDoc = deviceQuery.docs[0];
      const deviceData = deviceDoc.data();
      console.log(`   ✅ Found device: ID=${deviceDoc.id}, Data:`, deviceData);

      // Test vehicle lookup
      console.log("\n🔍 Testing vehicle lookup for this device:");
      const vehicleQuery = await db
        .collection("vehicles")
        .where("deviceId", "==", deviceDoc.id)
        .limit(1)
        .get();

      if (vehicleQuery.empty) {
        console.log(`   ❌ No vehicle found for device ID: ${deviceDoc.id}`);
      } else {
        const vehicleDoc = vehicleQuery.docs[0];
        const vehicleData = vehicleDoc.data();
        console.log(
          `   ✅ Found vehicle: ID=${vehicleDoc.id}, Data:`,
          vehicleData
        );
      }
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

testDeviceMapping().then(() => {
  console.log("\n✅ Test completed");
  process.exit(0);
});

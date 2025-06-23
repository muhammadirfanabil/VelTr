const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./firebase-admin-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function debugDeviceGeofences() {
  try {
    console.log("🔍 Debugging device and geofence relationship...\n");

    // Check for device B0A7322B2EC4 (the actual device ID from GPS logs)
    console.log("1. Checking device B0A7322B2EC4:");
    const deviceSnapshot = await db
      .collection("devices")
      .doc("B0A7322B2EC4")
      .get();
    if (deviceSnapshot.exists) {
      const deviceData = deviceSnapshot.data();
      console.log("   ✅ Device found in Firestore");
      console.log("   📝 Device name:", deviceData.name);
      console.log("   👤 Owner ID:", deviceData.ownerId);

      // Check geofences for this device ID
      const geofencesForDeviceId = await db
        .collection("geofences")
        .where("deviceId", "==", "B0A7322B2EC4")
        .get();
      console.log(
        `   🗺️ Geofences with deviceId='B0A7322B2EC4': ${geofencesForDeviceId.size}`
      );

      if (geofencesForDeviceId.size > 0) {
        geofencesForDeviceId.forEach((doc) => {
          const data = doc.data();
          console.log(
            `      - ${doc.id}: ${data.name} (owner: ${data.ownerId})`
          );
        });
      }
    } else {
      console.log("   ❌ Device B0A7322B2EC4 not found in Firestore");
    }

    console.log("\n2. Checking for device name TESTING2:");
    // Check if there's a device with name TESTING2
    const devicesByName = await db
      .collection("devices")
      .where("name", "==", "TESTING2")
      .get();

    if (devicesByName.size > 0) {
      devicesByName.forEach((doc) => {
        const data = doc.data();
        console.log(`   ✅ Device with name 'TESTING2' found: ${doc.id}`);
        console.log("   👤 Owner ID:", data.ownerId);
      });

      // Check geofences for device name TESTING2
      const geofencesForDeviceName = await db
        .collection("geofences")
        .where("deviceId", "==", "TESTING2")
        .get();
      console.log(
        `   🗺️ Geofences with deviceId='TESTING2': ${geofencesForDeviceName.size}`
      );

      if (geofencesForDeviceName.size > 0) {
        geofencesForDeviceName.forEach((doc) => {
          const data = doc.data();
          console.log(
            `      - ${doc.id}: ${data.name} (owner: ${data.ownerId})`
          );
        });
      }
    } else {
      console.log("   ❌ No device with name TESTING2 found");
    }

    console.log(
      "\n3. Checking all geofences for user kSOI63VB2oQ0QqBZzqmz81ps4363:"
    );
    const userGeofences = await db
      .collection("geofences")
      .where("ownerId", "==", "kSOI63VB2oQ0QqBZzqmz81ps4363")
      .get();

    console.log(`   🗺️ Total geofences for user: ${userGeofences.size}`);
    if (userGeofences.size > 0) {
      userGeofences.forEach((doc) => {
        const data = doc.data();
        console.log(
          `      - ${doc.id}: ${data.name} (deviceId: ${data.deviceId})`
        );
      });
    }

    console.log(
      "\n4. Checking all devices for user kSOI63VB2oQ0QqBZzqmz81ps4363:"
    );
    const userDevices = await db
      .collection("devices")
      .where("ownerId", "==", "kSOI63VB2oQ0QqBZzqmz81ps4363")
      .get();

    console.log(`   📱 Total devices for user: ${userDevices.size}`);
    if (userDevices.size > 0) {
      userDevices.forEach((doc) => {
        const data = doc.data();
        console.log(`      - ${doc.id}: name='${data.name}'`);
      });
    }
  } catch (error) {
    console.error("❌ Error debugging:", error);
  }
}

debugDeviceGeofences().then(() => {
  console.log("\n✅ Debug complete");
  process.exit(0);
});

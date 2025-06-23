// Simple script to check database collections
const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account
admin.initializeApp({
  projectId: "gps-project-a5c9a",
});

const db = admin.firestore();

async function checkCollections() {
  console.log("🔍 Debugging device and geofence relationship...");

  try {
    const userId = "kSOI63VB2oQ0QqBZzqmz81ps4363";

    // Check devices collection
    console.log("\n� Devices Collection:");
    const devicesSnapshot = await db
      .collection("devices")
      .where("ownerId", "==", userId)
      .get();
    console.log(`Found ${devicesSnapshot.size} devices for user`);

    devicesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(
        `- Device ID: ${doc.id}, Name: '${data.name}', Owner: ${data.ownerId}`
      );
    });

    // Check specific device B0A7322B2EC4
    console.log("\n🔍 Checking device B0A7322B2EC4:");
    const deviceB0A7 = await db.collection("devices").doc("B0A7322B2EC4").get();
    if (deviceB0A7.exists) {
      const data = deviceB0A7.data();
      console.log(
        `✅ Device found - Name: '${data.name}', Owner: ${data.ownerId}`
      );
    } else {
      console.log("❌ Device B0A7322B2EC4 not found");
    }

    // Check geofences collection
    console.log("\n🗺️ Geofences Collection:");
    const geofencesSnapshot = await db
      .collection("geofences")
      .where("ownerId", "==", userId)
      .get();
    console.log(`Found ${geofencesSnapshot.size} geofences for user`);

    geofencesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(
        `- Geofence ID: ${doc.id}, Name: '${data.name}', DeviceId: '${data.deviceId}', Owner: ${data.ownerId}`
      );
    });

    // Check geofences specifically for device B0A7322B2EC4
    console.log("\n🔍 Geofences for device B0A7322B2EC4:");
    const geofencesForB0A7 = await db
      .collection("geofences")
      .where("deviceId", "==", "B0A7322B2EC4")
      .get();
    console.log(
      `Found ${geofencesForB0A7.size} geofences with deviceId='B0A7322B2EC4'`
    );

    // Check geofences for device name TESTING2
    console.log("\n🔍 Geofences for device name TESTING2:");
    const geofencesForTEST2 = await db
      .collection("geofences")
      .where("deviceId", "==", "TESTING2")
      .get();
    console.log(
      `Found ${geofencesForTEST2.size} geofences with deviceId='TESTING2'`
    );

    if (geofencesForTEST2.size > 0) {
      geofencesForTEST2.forEach((doc) => {
        const data = doc.data();
        console.log(`  - ${doc.id}: '${data.name}' (owner: ${data.ownerId})`);
      });
    }

    // Check history collection
    console.log("\n📊 History Collection:");
    const historySnapshot = await db.collection("history").limit(10).get();
    console.log(`Found ${historySnapshot.size} history entries`);
    if (historySnapshot.size > 0) {
      historySnapshot.forEach((doc) => {
        const data = doc.data();
        console.log(
          `- History ID: ${doc.id}, Vehicle: ${
            data.vehicleId
          }, Created: ${data.createdAt?.toDate()}, Location: [${
            data.location?.latitude
          }, ${data.location?.longitude}]`
        );
      });
    } else {
      console.log("No history entries found");
    }
  } catch (error) {
    console.error("❌ Error checking collections:", error);
  } finally {
    process.exit(0);
  }
}

checkCollections();

// Simple script to check database collections
const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account
admin.initializeApp({
  projectId: "gps-project-a5c9a",
});

const db = admin.firestore();

async function checkCollections() {
  console.log("🔍 Checking database collections...");

  try {
    // Check vehicles collection
    console.log("\n📊 Vehicles Collection:");
    const vehiclesSnapshot = await db.collection("vehicles").limit(5).get();
    console.log(`Found ${vehiclesSnapshot.size} vehicles`);

    vehiclesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(
        `- Vehicle ID: ${doc.id}, Name: ${
          data.vehicleName || data.name
        }, Owner: ${data.ownerId}`
      );
    });

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

    // Check devices collection
    console.log("\n📊 Devices Collection:");
    const devicesSnapshot = await db.collection("devices").limit(5).get();
    console.log(`Found ${devicesSnapshot.size} devices`);

    devicesSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(
        `- Device ID: ${doc.id}, Name: ${data.deviceName}, Vehicle: ${data.vehicleId}, Owner: ${data.ownerId}`
      );
    });
  } catch (error) {
    console.error("❌ Error checking collections:", error);
  } finally {
    process.exit(0);
  }
}

checkCollections();

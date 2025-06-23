const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp({
  projectId: "gps-project-a5c9a",
  databaseURL:
    "https://gps-project-a5c9a-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.firestore();

async function createDeviceForDUMMY1() {
  console.log("🛠️ Creating Firestore device entry for DUMMY1...");

  try {
    // Create device document in Firestore
    const deviceData = {
      name: "DUMMY1",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Add other device fields if needed
      active: true,
      description: "Test device DUMMY1",
    };

    const deviceRef = await db.collection("devices").add(deviceData);
    console.log(`✅ Created device with ID: ${deviceRef.id}, Name: DUMMY1`);

    // Now create a vehicle linked to this device
    const vehicleData = {
      deviceId: deviceRef.id, // Link to the Firestore device document ID
      name: "Test Vehicle for DUMMY1",
      ownerId: "test-owner-id", // You may need to update this with a real owner ID
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      active: true,
    };

    const vehicleRef = await db.collection("vehicles").add(vehicleData);
    console.log(
      `✅ Created vehicle with ID: ${vehicleRef.id}, linked to device: ${deviceRef.id}`
    );

    console.log(
      "\n🎉 Setup complete! Now DUMMY1 should work with the history function."
    );
  } catch (error) {
    console.error("❌ Error creating device:", error);
  }
}

createDeviceForDUMMY1().then(() => {
  console.log("\n✅ Script completed");
  process.exit(0);
});

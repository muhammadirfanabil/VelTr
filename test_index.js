// Simple test to verify Firestore index is working
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

// Initialize Firebase Admin
initializeApp({
  projectId: "gps-project-a5c9a",
});

const db = getFirestore();

async function testIndex() {
  console.log("🧪 Testing Firestore index for history collection...");

  try {
    // Test the same query that the Cloud Function uses
    const threeDaysAgo = new Date();
    threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);

    console.log("📅 Testing query from:", threeDaysAgo.toISOString());

    const query = db
      .collection("history")
      .where("vehicleId", "==", "xYnKN2jEfG2yk5JLnpZW")
      .where("createdAt", ">=", threeDaysAgo)
      .orderBy("createdAt", "asc");

    console.log("🔍 Executing query...");
    const snapshot = await query.get();

    console.log("✅ Query successful!");
    console.log("📊 Found", snapshot.size, "documents");

    if (snapshot.size > 0) {
      console.log("📝 Sample document:");
      console.log(snapshot.docs[0].data());
    }
  } catch (error) {
    console.error("❌ Index test failed:", error.message);
    if (error.message.includes("requires an index")) {
      console.log(
        "🔧 Index is still building. Please wait a few more minutes."
      );
    }
  }
}

testIndex()
  .then(() => {
    console.log("🏁 Test completed");
    process.exit(0);
  })
  .catch((err) => {
    console.error("💥 Test failed:", err);
    process.exit(1);
  });

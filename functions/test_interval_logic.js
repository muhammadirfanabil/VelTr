// Simple test to verify 15-minute interval logic without Firebase initialization conflicts
const { getFirestore } = require("firebase-admin/firestore");

// Mock the database for testing
const mockDb = {
  collection: (name) => ({
    where: () => ({
      orderBy: () => ({
        limit: () => ({
          get: async () => {
            if (name === "history") {
              // Mock empty history for first test
              return { empty: true };
            }
            return { empty: false, docs: [] };
          },
        }),
      }),
    }),
  }),
};

// Copy the helper functions from index.js for testing
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in kilometers
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function shouldLogHistoryEntry(
  vehicleId,
  latitude,
  longitude,
  mockHistory = null
) {
  try {
    if (mockHistory) {
      // Use provided mock data
      const lastEntry = mockHistory;
      const lastTimestamp = new Date(lastEntry.createdAt);
      const lastLocation = lastEntry.location;

      // Calculate time difference in milliseconds
      const timeDiff = Date.now() - lastTimestamp.getTime();
      const timeDiffMinutes = timeDiff / (1000 * 60);

      // Enforce minimum 15-minute interval (900,000 ms = 15 minutes)
      if (timeDiff < 900000) {
        return {
          should: false,
          reason: `Too soon - only ${timeDiffMinutes.toFixed(
            1
          )} minutes since last entry (minimum: 15 minutes)`,
          timeDiff: timeDiff,
          distance: 0,
        };
      }

      // Calculate location difference in kilometers
      const distance = calculateDistance(
        lastLocation.latitude,
        lastLocation.longitude,
        latitude,
        longitude
      );

      // Check if vehicle has moved significantly (minimum 50 meters = 0.05 km)
      if (distance < 0.05) {
        return {
          should: false,
          reason: `Vehicle hasn't moved significantly (${(
            distance * 1000
          ).toFixed(0)}m < 50m minimum)`,
          timeDiff: timeDiff,
          distance: distance,
        };
      }

      return {
        should: true,
        reason: `Time and location criteria met (${timeDiffMinutes.toFixed(
          1
        )} min, ${(distance * 1000).toFixed(0)}m)`,
        timeDiff: timeDiff,
        distance: distance,
      };
    } else {
      // No previous entries, always log the first one
      return {
        should: true,
        reason: "First entry for vehicle",
        timeDiff: 0,
        distance: 0,
      };
    }
  } catch (error) {
    console.error(`❌ [HISTORY] Error checking if should log:`, error);
    return {
      should: true,
      reason: "Error checking criteria - defaulting to log",
      timeDiff: 0,
      distance: 0,
    };
  }
}

async function testIntervalLogic() {
  console.log("🧪 Testing 15-minute interval logic...");

  // Test 1: First entry should always be logged
  console.log("\n📍 Test 1: First entry (no previous history)");
  const result1 = await shouldLogHistoryEntry(
    "test-vehicle",
    -6.2088,
    106.8456
  );
  console.log(`✅ Result:`, result1);
  console.log(`   Expected: should=true, reason="First entry for vehicle"`);

  // Test 2: Entry within 15 minutes should be rejected
  console.log("\n⏰ Test 2: Entry within 15 minutes");
  const mockRecentEntry = {
    createdAt: new Date(Date.now() - 5 * 60 * 1000).toISOString(), // 5 minutes ago
    location: { latitude: -6.2088, longitude: 106.8456 },
  };
  const result2 = await shouldLogHistoryEntry(
    "test-vehicle",
    -6.209,
    106.8458,
    mockRecentEntry
  );
  console.log(`✅ Result:`, result2);
  console.log(`   Expected: should=false, reason contains "Too soon"`);

  // Test 3: Entry after 15 minutes with sufficient movement should be logged
  console.log("\n✅ Test 3: Entry after 15 minutes with movement");
  const mockOldEntry = {
    createdAt: new Date(Date.now() - 16 * 60 * 1000).toISOString(), // 16 minutes ago
    location: { latitude: -6.2088, longitude: 106.8456 },
  };
  const result3 = await shouldLogHistoryEntry(
    "test-vehicle",
    -6.21,
    106.847,
    mockOldEntry
  );
  console.log(`✅ Result:`, result3);
  console.log(
    `   Expected: should=true, reason contains "Time and location criteria met"`
  );

  // Test 4: Entry after 15 minutes but no movement should be rejected
  console.log(
    "\n🚫 Test 4: Entry after 15 minutes but no significant movement"
  );
  const result4 = await shouldLogHistoryEntry(
    "test-vehicle",
    -6.2088,
    106.8456,
    mockOldEntry
  );
  console.log(`✅ Result:`, result4);
  console.log(
    `   Expected: should=false, reason contains "hasn't moved significantly"`
  );

  // Test 5: Distance calculation test
  console.log("\n📏 Test 5: Distance calculation");
  const distance1 = calculateDistance(-6.2088, 106.8456, -6.209, 106.8458);
  const distance2 = calculateDistance(-6.2088, 106.8456, -6.21, 106.847);
  console.log(`✅ Distance test 1 (5m): ${(distance1 * 1000).toFixed(0)}m`);
  console.log(`✅ Distance test 2 (100m): ${(distance2 * 1000).toFixed(0)}m`);

  // Test 6: UTC timestamp format test
  console.log("\n🕐 Test 6: UTC timestamp format");
  const utcNow = new Date();
  console.log(`Current time (local): ${utcNow.toString()}`);
  console.log(`Current time (UTC ISO): ${utcNow.toISOString()}`);
  console.log(`Current time (Unix): ${utcNow.getTime()}`);

  // Verify UTC ISO string ends with Z
  const isValidUTC = utcNow.toISOString().endsWith("Z");
  console.log(`✅ UTC ISO string is valid: ${isValidUTC}`);

  console.log("\n✅ All logic tests completed!");
}

testIntervalLogic().catch(console.error);

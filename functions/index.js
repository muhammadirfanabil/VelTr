const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall } = require("firebase-functions/v2/https");
const { onValueWritten } = require("firebase-functions/v2/database");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// ===========================
// FUNCTION 1: Process Driving History - Log GPS data every 5 minutes
// if location changed
// ===========================
exports.processdrivinghistory = onValueWritten(
  {
    ref: "/devices/{deviceId}/gps",
    region: "asia-southeast1",
  },
  async (event) => {
    const gpsData = event.data.after.val();
    const { deviceId } = event.params;
    const timestamp = new Date();

    console.log(`🛰️ [HISTORY] Processing GPS data for device: ${deviceId}`);

    try {
      // Validate GPS data
      if (
        !gpsData ||
        typeof gpsData.latitude !== "number" ||
        typeof gpsData.longitude !== "number"
      ) {
        console.log(`❌ [HISTORY] Invalid GPS data for device: ${deviceId}`);
        return { success: false, message: "Invalid GPS data" };
      }

      const { latitude, longitude } = gpsData;

      // Get device info by querying the name field
      console.log(
        `🔍 [HISTORY] Searching for device with name: "${deviceId}" (length: ${deviceId.length})`
      );
      console.log(
        `🔍 [HISTORY] Device name bytes:`,
        Array.from(deviceId).map((c) => c.charCodeAt(0))
      );

      // Try exact match first
      let deviceQuery = await db
        .collection("devices")
        .where("name", "==", deviceId)
        .limit(1)
        .get();

      // If no exact match, try case-insensitive search
      if (deviceQuery.empty) {
        console.log(
          `🔍 [HISTORY] No exact match, trying case-insensitive search...`
        );
        const allDevicesQuery = await db.collection("devices").get();
        let matchingDevice = null;

        allDevicesQuery.forEach((doc) => {
          const data = doc.data();
          if (data.name && data.name.toLowerCase() === deviceId.toLowerCase()) {
            matchingDevice = doc;
            console.log(
              `✅ [HISTORY] Found case-insensitive match: "${data.name}"`
            );
          }
        });

        if (matchingDevice) {
          // Create a mock query result
          deviceQuery = {
            empty: false,
            docs: [matchingDevice],
          };
        }
      }

      if (deviceQuery.empty) {
        console.log(`❌ [HISTORY] Device not found: ${deviceId}`);

        // Debug: List all available devices to help diagnose the issue
        console.log(`🔍 [HISTORY] Listing all devices for debugging:`);
        try {
          const allDevicesQuery = await db
            .collection("devices")
            .limit(10)
            .get();
          if (allDevicesQuery.empty) {
            console.log(`   No devices found in Firestore collection`);
          } else {
            allDevicesQuery.forEach((doc) => {
              const data = doc.data();
              console.log(
                `   Device ID: ${doc.id}, Name: "${
                  data.name || "N/A"
                }" (length: ${(data.name || "").length})`
              );
            });
          }
        } catch (debugError) {
          console.log(`   Error listing devices:`, debugError);
        }

        // Auto-create device if it doesn't exist (for testing/development)
        console.log(`🛠️ [HISTORY] Auto-creating device for: ${deviceId}`);
        try {
          const newDeviceData = {
            name: deviceId,
            createdAt: timestamp,
            updatedAt: timestamp,
            active: true,
            description: `Auto-created device for ${deviceId}`,
            autoCreated: true,
          };

          const newDeviceRef = await db
            .collection("devices")
            .add(newDeviceData);
          console.log(
            `✅ [HISTORY] Auto-created device: ${newDeviceRef.id} for name: ${deviceId}`
          );

          // Also create a basic vehicle linked to this device
          const newVehicleData = {
            deviceId: newDeviceRef.id,
            name: `Auto Vehicle for ${deviceId}`,
            ownerId: "auto-owner", // Default owner for auto-created devices
            createdAt: timestamp,
            updatedAt: timestamp,
            active: true,
            autoCreated: true,
          };

          const newVehicleRef = await db
            .collection("vehicles")
            .add(newVehicleData);
          console.log(
            `✅ [HISTORY] Auto-created vehicle: ${newVehicleRef.id} for device: ${newDeviceRef.id}`
          );

          // Now continue with the newly created device
          const firestoreDeviceId = newDeviceRef.id;
          const vehicleId = newVehicleRef.id;
          const ownerId = "auto-owner";

          // Check if we should log this entry
          const shouldLog = await shouldLogHistoryEntry(
            vehicleId,
            latitude,
            longitude
          );
          if (!shouldLog.should) {
            console.log(`⏭️ [HISTORY] Skipping entry: ${shouldLog.reason}`);
            return { success: true, message: shouldLog.reason };
          }

          // Create history entry
          const historyData = {
            createdAt: timestamp,
            updatedAt: timestamp,
            vehicleId: vehicleId,
            ownerId: ownerId,
            deviceName: deviceId,
            firestoreDeviceId: firestoreDeviceId,
            location: {
              latitude: latitude,
              longitude: longitude,
            },
          };

          await db.collection("history").add(historyData);

          console.log(
            `✅ [HISTORY] Entry logged for auto-created vehicle: ${vehicleId} (device: ${deviceId}) at (${latitude}, ${longitude})`
          );
          return {
            success: true,
            message: `History entry logged for auto-created vehicle ${vehicleId} (device: ${deviceId})`,
            timestamp: timestamp.toISOString(),
            vehicleId: vehicleId,
            deviceName: deviceId,
            autoCreated: true,
          };
        } catch (autoCreateError) {
          console.error(
            `❌ [HISTORY] Error auto-creating device:`,
            autoCreateError
          );
          return {
            success: false,
            message: "Device not found and auto-creation failed",
          };
        }
      }

      const deviceDoc = deviceQuery.docs[0];
      const deviceData = deviceDoc.data();
      const firestoreDeviceId = deviceDoc.id;

      console.log(
        `✅ [HISTORY] Found device: ${firestoreDeviceId} for name: ${deviceId}`
      );
      console.log(`🔍 [HISTORY] Device data:`, JSON.stringify(deviceData));

      // Get vehicle info using the vehicleId from the device document
      const deviceVehicleId = deviceData.vehicleId;
      if (!deviceVehicleId) {
        console.log(`❌ [HISTORY] No vehicleId found in device: ${deviceId}`);
        return { success: false, message: "No vehicleId linked to device" };
      }

      console.log(
        `🔍 [HISTORY] Looking for vehicle with ID: ${deviceVehicleId}`
      );
      const vehicleDoc = await db
        .collection("vehicles")
        .doc(deviceVehicleId)
        .get();

      if (!vehicleDoc.exists) {
        console.log(
          `❌ [HISTORY] Vehicle not found for ID: ${deviceVehicleId}`
        );
        return { success: false, message: "Vehicle not found" };
      }

      const vehicleData = vehicleDoc.data();
      const vehicleId = vehicleDoc.id;
      const ownerId = vehicleData.ownerId;

      console.log(
        `🚗 [HISTORY] Found vehicle: ${vehicleId} for device: ${deviceId}`
      );

      if (!ownerId) {
        console.log(
          `❌ [HISTORY] Missing ownerId for vehicle: ${vehicleId}, device: ${deviceId}`
        );
        return { success: false, message: "Missing ownerId" };
      }

      // Check if we should log this entry (5-minute cooldown and location change)
      const shouldLog = await shouldLogHistoryEntry(
        vehicleId,
        latitude,
        longitude
      );
      if (!shouldLog.should) {
        console.log(`⏭️ [HISTORY] Skipping entry: ${shouldLog.reason}`);
        return { success: true, message: shouldLog.reason };
      }

      // Create history entry
      const historyData = {
        createdAt: timestamp,
        updatedAt: timestamp,
        vehicleId: vehicleId,
        ownerId: ownerId,
        deviceName: deviceId, // Store the original device name for reference
        firestoreDeviceId: firestoreDeviceId, // Store Firestore document ID
        location: {
          latitude: latitude,
          longitude: longitude,
        },
      };

      // Save to history collection
      await db.collection("history").add(historyData);

      console.log(
        `✅ [HISTORY] Entry logged for vehicle: ${vehicleId} (device: ${deviceId}) at (${latitude}, ${longitude})`
      );
      return {
        success: true,
        message: `History entry logged for vehicle ${vehicleId} (device: ${deviceId})`,
        timestamp: timestamp.toISOString(),
        vehicleId: vehicleId,
        deviceName: deviceId,
      };
    } catch (error) {
      console.error(`❌ [HISTORY] Error processing history:`, error);
      return {
        success: false,
        message: error.message,
        timestamp: timestamp.toISOString(),
      };
    }
  }
);

// Helper function to determine if we should log a history entry
async function shouldLogHistoryEntry(vehicleId, latitude, longitude) {
  try {
    // Get the most recent history entry for this vehicle
    const recentQuery = await db
      .collection("history")
      .where("vehicleId", "==", vehicleId)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (recentQuery.empty) {
      // No previous entries, always log the first one
      return { should: true, reason: "First entry for vehicle" };
    }

    const lastEntry = recentQuery.docs[0].data();
    const lastTimestamp = lastEntry.createdAt.toDate();
    const lastLocation = lastEntry.location;

    // Check time difference (5 seconds = 5,000 ms)
    const timeDiff = Date.now() - lastTimestamp.getTime();
    if (timeDiff < 5000) {
      // Less than 5 seconds
      return {
        should: false,
        reason: "Too soon - less than 5 seconds since last entry",
      };
    }

    // Check location difference (minimum 10 meters to avoid logging stationary vehicle)
    const distance = calculateDistance(
      lastLocation.latitude,
      lastLocation.longitude,
      latitude,
      longitude
    );

    if (distance < 0.01) {
      // Less than 10 meters
      return { should: false, reason: "Vehicle hasn't moved significantly" };
    }

    return { should: true, reason: "Time and location criteria met" };
  } catch (error) {
    console.error(`❌ [HISTORY] Error checking if should log:`, error);
    // Default to logging if we can't check
    return {
      should: true,
      reason: "Error checking criteria - defaulting to log",
    };
  }
}

// Helper function to calculate distance between two coordinates (in km)
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

// ===========================
// FUNCTION 2: Cleanup Driving History - Delete entries older than 7 days
// ===========================
exports.cleanupdrivinghistory = onSchedule(
  {
    schedule: "0 3 * * *", // Run daily at 3 AM
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log("🧹 [CLEANUP] Starting driving history cleanup");

    try {
      // Calculate 7 days ago
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      console.log(
        `📅 [CLEANUP] Deleting entries older than: ${sevenDaysAgo.toISOString()}`
      );

      // Query entries older than 7 days
      const oldEntriesQuery = await db
        .collection("history")
        .where("createdAt", "<", sevenDaysAgo)
        .limit(500) // Process in batches to avoid timeouts
        .get();

      if (oldEntriesQuery.empty) {
        console.log("✅ [CLEANUP] No old entries found to delete");
        return {
          message: "Cleanup completed - no old entries found",
          deletedCount: 0,
          timestamp: new Date().toISOString(),
        };
      }

      // Delete entries in batch
      const batch = db.batch();
      let deleteCount = 0;

      oldEntriesQuery.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deleteCount++;
      });

      await batch.commit();

      console.log(
        `✅ [CLEANUP] Successfully deleted ${deleteCount} old history entries`
      );

      return {
        message: `Cleanup completed - deleted ${deleteCount} entries`,
        deletedCount: deleteCount,
        cutoffDate: sevenDaysAgo.toISOString(),
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error(`❌ [CLEANUP] Error during cleanup:`, error);
      return {
        message: "Cleanup failed",
        error: error.message,
        timestamp: new Date().toISOString(),
      };
    }
  }
);

// ===========================
// FUNCTION 3: Query Driving History - Fetch history data for a vehicle
// ===========================
exports.querydrivinghistory = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    console.log(`📊 Query function called`);

    if (!request.auth) {
      console.log(`❌ [QUERY] Authentication required`);
      throw new Error("Authentication required");
    }

    const { vehicleId, days = 7 } = request.data;
    const userId = request.auth.uid;

    console.log(
      `📊 [QUERY] Fetching history for vehicle: ${vehicleId}, user: ${userId}, days: ${days}`
    );
    console.log(`📊 [QUERY] Request data:`, JSON.stringify(request.data));

    try {
      // Validate input
      if (!vehicleId) {
        throw new Error("vehicleId is required");
      }

      // Verify user owns this vehicle
      const vehicleDoc = await db.collection("vehicles").doc(vehicleId).get();
      if (!vehicleDoc.exists) {
        throw new Error("Vehicle not found");
      }

      const vehicleData = vehicleDoc.data();
      if (vehicleData.ownerId !== userId) {
        throw new Error("Access denied - user does not own this vehicle");
      }

      // Calculate date range
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      console.log(
        `📅 [QUERY] Fetching entries from: ${startDate.toISOString()}`
      );

      // Query history entries
      const historyQuery = await db
        .collection("history")
        .where("vehicleId", "==", vehicleId)
        .where("createdAt", ">=", startDate)
        .orderBy("createdAt", "asc")
        .limit(1000) // Reasonable limit
        .get();

      const historyEntries = [];
      historyQuery.docs.forEach((doc) => {
        const data = doc.data();
        historyEntries.push({
          id: doc.id,
          createdAt: data.createdAt.toDate().toISOString(),
          location: {
            latitude: Number(data.location.latitude),
            longitude: Number(data.location.longitude),
          },
          vehicleId: data.vehicleId,
          ownerId: data.ownerId || userId, // Include ownerId field
        });
      });

      console.log(`✅ [QUERY] Found ${historyEntries.length} history entries`);

      const response = {
        success: true,
        entries: historyEntries,
        totalCount: historyEntries.length,
        vehicleId: vehicleId,
        dateRange: {
          from: startDate.toISOString(),
          to: new Date().toISOString(),
        },
      };

      console.log(
        `📤 [QUERY] Returning response:`,
        JSON.stringify(response, null, 2)
      );
      return response;
    } catch (error) {
      console.error(`❌ [QUERY] Error fetching history:`, error);
      throw new Error(`Failed to fetch driving history: ${error.message}`);
    }
  }
);

// ===========================
// FUNCTION 4: Robust Geofence Status Detection System
// ===========================
exports.geofencechangestatus = onValueWritten(
  {
    ref: "/devices/{deviceId}/gps",
    region: "asia-southeast1",
  },
  async (event) => {
    const gpsData = event.data.after.val();
    const { deviceId } = event.params;
    const timestamp = new Date();

    console.log(`🎯 [GEOFENCE] Starting status check for device: ${deviceId}`);
    console.log(`📍 [GPS] Data received:`, gpsData);

    try {
      // ===== STEP 1: Validate GPS Data =====
      const validationResult = validateGPSData(gpsData);
      if (!validationResult.isValid) {
        console.log(`❌ [VALIDATION] ${validationResult.error}`);
        return {
          success: false,
          message: validationResult.error,
          deviceIdentifier: deviceId,
        };
      }

      const { latitude, longitude } = validationResult;
      console.log(`✅ [GPS] Valid coordinates: ${latitude}, ${longitude}`);

      // ===== STEP 2: Get Device Owner =====
      // Query device by name (deviceId from RTDB path)
      console.log(`🔍 [DEVICE] Looking up device by name: ${deviceId}`);
      const deviceQuery = await db
        .collection("devices")
        .where("name", "==", deviceId)
        .limit(1)
        .get();

      if (deviceQuery.empty) {
        console.log(`❌ [DEVICE] No device found with name: ${deviceId}`);
        return {
          success: false,
          message: `Device not found with name: ${deviceId}`,
        };
      }

      const deviceDoc = deviceQuery.docs[0];
      const deviceData = deviceDoc.data();
      const ownerId = deviceData.ownerId;
      const deviceName = deviceData.name || deviceId;
      const firestoreDeviceId = deviceDoc.id;

      if (!ownerId) {
        console.log(`⚠️ [DEVICE] No owner found for device: ${deviceId}`);
        return {
          success: false,
          message: "Device has no owner",
          deviceIdentifier: deviceId,
          firestoreDeviceId: firestoreDeviceId,
        };
      }

      console.log(
        `👤 [OWNER] Device owner: ${ownerId}, Device name: ${deviceName}, ` +
          `Device ID: ${deviceId}, Firestore ID: ${firestoreDeviceId}`
      );

      // ===== STEP 3: Get Active Geofences =====
      const geofencesSnapshot = await db
        .collection("geofences")
        .where("deviceId", "==", firestoreDeviceId)
        .where("ownerId", "==", ownerId)
        .where("status", "==", true)
        .get();

      if (geofencesSnapshot.empty) {
        console.log(
          `📍 [GEOFENCES] No active geofences for device: ${deviceName}`
        );
        return {
          success: true,
          message: "No active geofences",
          deviceId: firestoreDeviceId,
          deviceIdentifier: deviceId,
          deviceName: deviceName,
        };
      }

      console.log(
        `🔍 [GEOFENCES] Found ${geofencesSnapshot.size} active geofences`
      );

      // ===== STEP 4: Process Each Geofence =====
      const processedResults = [];
      const batch = db.batch();

      for (const geofenceDoc of geofencesSnapshot.docs) {
        const geofence = geofenceDoc.data();
        const geofenceId = geofenceDoc.id;

        console.log(`🎯 [PROCESSING] Checking geofence: "${geofence.name}"`);

        // Validate geofence polygon
        if (!geofence.points || geofence.points.length < 3) {
          console.log(`⚠️ [GEOFENCE] Invalid polygon for: ${geofence.name}`);
          continue;
        }

        // Check if GPS point is inside geofence polygon
        const isCurrentlyInside = isPointInPolygon(
          { lat: latitude, lng: longitude },
          geofence.points
        );

        console.log(
          `📊 [DETECTION] Point is ${
            isCurrentlyInside ? "INSIDE" : "OUTSIDE"
          } geofence "${geofence.name}"`
        );

        // Get previous status
        const previousStatus = await getPreviousGeofenceStatus(
          firestoreDeviceId,
          geofenceId
        );
        console.log(
          `📝 [HISTORY] Previous status: ${
            previousStatus === null
              ? "UNKNOWN"
              : previousStatus
              ? "INSIDE"
              : "OUTSIDE"
          }`
        );

        // Detect status change
        const hasStatusChanged = previousStatus !== isCurrentlyInside;

        if (hasStatusChanged) {
          const action = isCurrentlyInside ? "ENTER" : "EXIT";
          const status = isCurrentlyInside ? "inside" : "outside";

          console.log(
            `🚨 [CHANGE DETECTED] ${action} detected for "${geofence.name}"`
          );
          // Create log entry
          const logData = {
            deviceId: firestoreDeviceId,
            deviceIdentifier: deviceId,
            deviceName: deviceName,
            geofenceId: geofenceId,
            geofenceName: geofence.name,
            ownerId: ownerId,
            action: action.toLowerCase(),
            status: status,
            location: {
              latitude: latitude,
              longitude: longitude,
            },
            timestamp: FieldValue.serverTimestamp(),
            createdAt: timestamp,
            processedAt: new Date(),
          };

          // Add to batch
          const logRef = db.collection("geofence_logs").doc();
          batch.set(logRef, logData);

          // Check cooldown before sending FCM notification
          const canSend = await canSendNotification(firestoreDeviceId, geofence.name, 2);
          if (canSend) {
            // Send FCM notification
            await sendGeofenceNotification({
              deviceId: firestoreDeviceId,
              deviceIdentifier: deviceId,
              deviceName: deviceName,
              geofenceName: geofence.name,
              ownerId: ownerId,
              action: action,
              location: { latitude, longitude },
              timestamp: timestamp,
            });
          } else {
            console.log(
              `⏰ [COOLDOWN] Skipping notification for ${deviceName} @ ${geofence.name} (${action})`
            );
          }

          processedResults.push({
            geofenceId: geofenceId,
            geofenceName: geofence.name,
            action: action,
            status: status,
            previousStatus:
              previousStatus === null
                ? "unknown"
                : previousStatus
                ? "inside"
                : "outside",
          });
        } else {
          console.log(`ℹ️ [NO_CHANGE] Status unchanged for "${geofence.name}"`);
        }
      }

      // ===== STEP 5: Commit Logs =====
      if (processedResults.length > 0) {
        await batch.commit();
        console.log(
          `✅ [COMMIT] Logged ${processedResults.length} status changes`
        );
      }

      return {
        success: true,
        message: `Processed ${geofencesSnapshot.size} geofences`,
        deviceId: firestoreDeviceId,
        deviceIdentifier: deviceId,
        deviceName: deviceName,
        statusChanges: processedResults.length,
        changes: processedResults,
        location: { latitude, longitude },
        timestamp: timestamp.toISOString(),
      };
    } catch (error) {
      console.error(`❌ [ERROR] Processing failed:`, error);
      return {
        success: false,
        error: error.message,
        deviceIdentifier: deviceId,
        timestamp: timestamp.toISOString(),
      };
    }
  }
);

// ===========================
// HELPER FUNCTIONS
// ===========================

/**
 * Validate GPS data from various possible field structures
 * @param {Object} gpsData - GPS data object
 * @return {Object} {isValid: boolean, latitude?: number,
 *   longitude?: number, error?: string}
 */
function validateGPSData(gpsData) {
  if (!gpsData || typeof gpsData !== "object") {
    return {
      isValid: false,
      error: "GPS data is missing or invalid",
    };
  }

  // Try different possible field names and structures
  let latitude;
  let longitude;

  // Check for common field variations
  if (gpsData.latitude !== undefined && gpsData.longitude !== undefined) {
    latitude = gpsData.latitude;
    longitude = gpsData.longitude;
  } else if (gpsData.lat !== undefined && gpsData.lng !== undefined) {
    latitude = gpsData.lat;
    longitude = gpsData.lng;
  } else if (gpsData.lat !== undefined && gpsData.lon !== undefined) {
    latitude = gpsData.lat;
    longitude = gpsData.lon;
  } else if (gpsData.location && typeof gpsData.location === "object") {
    const loc = gpsData.location;
    if (loc.latitude !== undefined && loc.longitude !== undefined) {
      latitude = loc.latitude;
      longitude = loc.longitude;
    } else if (loc.lat !== undefined && loc.lng !== undefined) {
      latitude = loc.lat;
      longitude = loc.lng;
    }
  }

  // Convert to numbers if they're strings
  if (typeof latitude === "string") latitude = parseFloat(latitude);
  if (typeof longitude === "string") longitude = parseFloat(longitude);

  // Validate the coordinates
  if (typeof latitude !== "number" || typeof longitude !== "number") {
    return {
      isValid: false,
      error: "Invalid GPS coordinates: latitude or longitude missing/invalid",
    };
  }

  if (isNaN(latitude) || isNaN(longitude)) {
    return {
      isValid: false,
      error: "Invalid GPS coordinates: latitude or longitude are NaN",
    };
  }

  // Check if coordinates are within valid ranges
  if (latitude < -90 || latitude > 90) {
    return {
      isValid: false,
      error: `Invalid latitude: ${latitude} (must be between -90 and 90)`,
    };
  }

  if (longitude < -180 || longitude > 180) {
    return {
      isValid: false,
      error: `Invalid longitude: ${longitude} (must be between -180 and 180)`,
    };
  }

  return {
    isValid: true,
    latitude: latitude,
    longitude: longitude,
  };
}

/**
 * Check if a point is inside a polygon using ray casting algorithm
 * @param {Object} point - {lat, lng}
 * @param {Array} polygon - Array of {latitude, longitude} points
 * @return {boolean} True if point is inside polygon
 */
function isPointInPolygon(point, polygon) {
  if (!point || !polygon || polygon.length < 3) {
    return false;
  }

  const x = point.lng;
  const y = point.lat;
  let inside = false;

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    // Handle different field name variations
    const xi = polygon[i].longitude || polygon[i].lng || 0;
    const yi = polygon[i].latitude || polygon[i].lat || 0;
    const xj = polygon[j].longitude || polygon[j].lng || 0;
    const yj = polygon[j].latitude || polygon[j].lat || 0;

    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }

  return inside;
}

/**
 * Get the previous geofence status for a device from logs
 * @param {string} deviceId - Device ID
 * @param {string} geofenceId - Geofence ID
 * @return {boolean|null} Previous status or null if no previous record
 */
async function getPreviousGeofenceStatus(deviceId, geofenceId) {
  try {
    const logsSnapshot = await db
      .collection("geofence_logs")
      .where("deviceId", "==", deviceId)
      .where("geofenceId", "==", geofenceId)
      .orderBy("timestamp", "desc")
      .limit(1)
      .get();

    if (!logsSnapshot.empty) {
      const lastLog = logsSnapshot.docs[0].data();
      return lastLog.status === "inside";
    }

    return null; // No previous status found
  } catch (error) {
    console.error("Error getting previous status:", error);
    return null;
  }
}

/**
 * Send geofence notification via FCM and log to database
 * @param {Object} params - Notification parameters
 * @param {string} params.ownerId - Owner ID
 * @param {string} params.deviceId - Device ID
 * @param {string} params.deviceName - Device name
 * @param {string} params.geofenceName - Geofence name
 * @param {string} params.action - ENTER or EXIT
 * @param {Object} params.location - {latitude, longitude}
 * @param {Date} params.timestamp - Event timestamp
 */
async function sendGeofenceNotification(params) {
  try {
    const {
      ownerId,
      deviceId,
      deviceIdentifier,
      deviceName,
      geofenceName,
      action,
      location,
      timestamp,
    } = params;

    console.log(
      `📱 [NOTIFICATION] Sending ${action} notification for "${geofenceName}"`
    );
    console.log(`🔍 [DEBUG] Notification params:`, {
      ownerId,
      deviceId: deviceId.substring(0, 10) + '...',
      deviceName,
      geofenceName,
      action
    });

    // Get user's FCM tokens
    const userDoc = await db.collection("users_information").doc(ownerId).get();
    if (!userDoc.exists) {
      console.log(`⚠️ [FCM] User not found: ${ownerId}`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    console.log(`🔍 [FCM_TOKENS] Found ${fcmTokens.length} tokens for user ${ownerId}`);
    if (fcmTokens.length > 0) {
      console.log(`🔍 [FCM_TOKENS] First token: ${fcmTokens[0].substring(0, 20)}...`);
    }

    if (fcmTokens.length === 0) {
      console.log(`⚠️ [FCM] No FCM tokens found for user: ${ownerId}`);
      return;
    }

    // Prepare notification message
    const actionText = action === "ENTER" ? "entered" : "exited";
    const title = `Geofence Alert`;
    const body = `${deviceName} has ${actionText} ${geofenceName}`;

    console.log(`🔔 [FCM] Preparing to send notification: "${title}" - "${body}"`);

    // Prepare FCM payload (data-only message to prevent system notifications)
    const message = {
      data: {
        type: "geofence_alert",
        deviceId: deviceId,
        deviceName: deviceName,
        geofenceName: geofenceName,
        action: action.toLowerCase(),
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        timestamp: timestamp.toISOString(),
        // Include title and body in data for app to handle
        title: title,
        body: body,
      },
      android: {
        priority: "high",
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
          },
        },
      },
    };

    // Send to all valid tokens
    const validTokens = [];
    const invalidTokens = [];

    for (const token of fcmTokens) {
      try {
        await messaging.send({
          ...message,
          token: token,
        });
        validTokens.push(token);
        console.log(
          `✅ [FCM] Notification sent to token: ${token.substring(0, 20)}...`
        );
      } catch (error) {
        console.log(
          `❌ [FCM] Failed to send to token: ${token.substring(0, 20)}...`,
          error.code
        );
        if (
          error.code === "messaging/registration-token-not-registered" ||
          error.code === "messaging/invalid-registration-token"
        ) {
          invalidTokens.push(token);
        }
      }
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      await cleanupInvalidFCMTokens(ownerId, invalidTokens);
    }

    // Log notification to database
    const notificationData = {
      ownerId: ownerId,
      deviceId: deviceId,
      deviceIdentifier: deviceIdentifier,
      deviceName: deviceName,
      geofenceName: geofenceName,
      action: action.toLowerCase(),
      message: body,
      location: location,
      timestamp: FieldValue.serverTimestamp(),
      createdAt: timestamp,
      read: false,
      sentToTokens: validTokens.length,
      totalTokens: fcmTokens.length,
    };

    await db.collection("notifications").add(notificationData);

    console.log(
      `✅ [NOTIFICATION] Sent to ${validTokens.length}/` +
        `${fcmTokens.length} tokens`
    );
  } catch (error) {
    console.error("❌ [NOTIFICATION] Error sending notification:", error);
  }
}

/**
 * Clean up invalid FCM tokens from user document
 * @param {string} userId - User ID
 * @param {Array} invalidTokens - Array of invalid tokens to remove
 */
async function cleanupInvalidFCMTokens(userId, invalidTokens) {
  try {
    const userRef = db.collection("users_information").doc(userId);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
      const userData = userDoc.data();
      const currentTokens = userData.fcmTokens || [];
      const validTokens = currentTokens.filter(
        (token) => !invalidTokens.includes(token)
      );

      await userRef.update({
        fcmTokens: validTokens,
      });

      console.log(
        `🧹 [FCM_CLEANUP] Removed ${invalidTokens.length} invalid ` +
          `tokens for user: ${userId}`
      );
    }
  } catch (error) {
    console.error("❌ [FCM_CLEANUP] Error cleaning up tokens:", error);
  }
}

/**
 * Check if enough time has passed since the last notification for cooldown
 * @param {string} deviceId - Device ID
 * @param {string} geofenceId - Geofence ID
 * @param {number} cooldownMinutes - Cooldown period in minutes (default 2)
 * @return {boolean} True if enough time has passed
 */
async function canSendNotification(deviceId, geofenceId, cooldownMinutes = 2) {
  try {
    const cooldownMs = cooldownMinutes * 60 * 1000; // Convert to milliseconds
    const cutoffTime = new Date(Date.now() - cooldownMs);

    const recentNotification = await db
      .collection("notifications")
      .where("deviceId", "==", deviceId)
      .where("geofenceName", "==", geofenceId)
      .where("timestamp", ">=", cutoffTime)
      .limit(1)
      .get();

    const canSend = recentNotification.empty;
    
    if (!canSend) {
      console.log(
        `🚫 [COOLDOWN] Notification blocked for ${deviceId}@${geofenceId} ` +
        `(cooldown: ${cooldownMinutes}min)`
      );
    }

    return canSend;
  } catch (error) {
    console.error("Error checking notification cooldown:", error);
    return true; // Default to allowing notification if check fails
  }
}

// ===========================
// FUNCTION 5: Query Geofence Logs
// ===========================
exports.querygeofencelogs = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("Authentication required");
    }

    try {
      const { deviceId, startDate, endDate, limit = 50 } = request.data;
      const userId = request.auth.uid;

      if (!deviceId) {
        throw new Error("Device ID is required");
      }

      console.log(`📊 Querying geofence logs for device: ${deviceId}`);

      let query = db
        .collection("geofence_logs")
        .where("deviceId", "==", deviceId)
        .where("ownerId", "==", userId);

      // Add date filters if provided
      if (startDate) {
        query = query.where("timestamp", ">=", new Date(startDate));
      }
      if (endDate) {
        query = query.where("timestamp", "<=", new Date(endDate));
      }

      const logsSnapshot = await query
        .orderBy("timestamp", "desc")
        .limit(limit)
        .get();

      const logs = logsSnapshot.docs.map((doc) => {
        const data = doc.data();
        const timestamp =
          data.timestamp && data.timestamp.toDate
            ? data.timestamp.toDate()
            : data.createdAt;

        return {
          id: doc.id,
          ...data,
          timestamp: timestamp,
        };
      });

      return {
        success: true,
        logs: logs,
        count: logs.length,
      };
    } catch (error) {
      console.error("❌ Error querying geofence logs:", error);
      throw new Error(`Failed to query logs: ${error.message}`);
    }
  }
);

// ===========================
// FUNCTION 6: Get Geofence Statistics
// ===========================
exports.getgeofencestats = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("Authentication required");
    }

    try {
      const { deviceId, days = 7 } = request.data;
      const userId = request.auth.uid;

      if (!deviceId) {
        throw new Error("Device ID is required");
      }

      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      console.log(`📈 Getting geofence stats for device: ${deviceId}`);

      // Get logs from the specified period
      const logsSnapshot = await db
        .collection("geofence_logs")
        .where("deviceId", "==", deviceId)
        .where("ownerId", "==", userId)
        .where("timestamp", ">=", startDate)
        .get();

      const logs = logsSnapshot.docs.map((doc) => doc.data());

      // Calculate statistics
      const stats = {
        totalEvents: logs.length,
        enterEvents: logs.filter((log) => log.action === "enter").length,
        exitEvents: logs.filter((log) => log.action === "exit").length,
        geofencesTriggered: [...new Set(logs.map((log) => log.geofenceId))]
          .length,
        period: days,
        deviceId: deviceId,
      };

      // Get current status for each geofence
      const geofencesSnapshot = await db
        .collection("geofences")
        .where("deviceId", "==", deviceId)
        .where("ownerId", "==", userId)
        .where("status", "==", true)
        .get();

      const currentStatus = [];
      for (const geofenceDoc of geofencesSnapshot.docs) {
        const geofence = geofenceDoc.data();
        const lastLogSnapshot = await db
          .collection("geofence_logs")
          .where("deviceId", "==", deviceId)
          .where("geofenceId", "==", geofenceDoc.id)
          .orderBy("timestamp", "desc")
          .limit(1)
          .get();

        const status = lastLogSnapshot.empty
          ? "unknown"
          : lastLogSnapshot.docs[0].data().status;

        currentStatus.push({
          geofenceId: geofenceDoc.id,
          geofenceName: geofence.name,
          status: status,
        });
      }

      return {
        success: true,
        stats: stats,
        currentStatus: currentStatus,
      };
    } catch (error) {
      console.error("❌ Error getting geofence stats:", error);
      throw new Error(`Failed to get stats: ${error.message}`);
    }
  }
);

// ===========================
// DEBUG FUNCTION: Test FCM Notification manually
// ===========================
exports.testfcmnotification = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("Authentication required");
    }

    try {
      const userId = request.auth.uid;
      
      console.log(`🧪 [TEST_FCM] Testing notification for user: ${userId}`);
      
      // Get user's FCM tokens
      const userDoc = await db.collection("users_information").doc(userId).get();
      if (!userDoc.exists) {
        throw new Error("User not found");
      }

      const userData = userDoc.data();
      const fcmTokens = userData.fcmTokens || [];

      if (fcmTokens.length === 0) {
        throw new Error("No FCM tokens found for user");
      }

      console.log(`🔍 [TEST_FCM] Found ${fcmTokens.length} FCM tokens`);

      // Test notification payload
      const testMessage = {
        data: {
          type: "geofence_alert",
          deviceId: "test_device",
          deviceName: "Test Vehicle",
          geofenceName: "Test Geofence",
          action: "enter",
          latitude: "-6.2088",
          longitude: "106.8456",
          timestamp: new Date().toISOString(),
          title: "🧪 Test Geofence Alert",
          body: "This is a manual test notification to verify FCM delivery",
        },
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
        },
      };

      // Send to first token
      const testToken = fcmTokens[0];
      console.log(`📤 [TEST_FCM] Sending to token: ${testToken.substring(0, 20)}...`);

      await messaging.send({
        ...testMessage,
        token: testToken,
      });

      // Store test notification in database
      const notificationData = {
        ownerId: userId,
        deviceId: "test_device",
        deviceIdentifier: "test_device", 
        deviceName: "Test Vehicle",
        geofenceName: "Test Geofence",
        action: "enter",
        message: "This is a manual test notification to verify FCM delivery",
        location: {
          latitude: -6.2088,
          longitude: 106.8456,
        },
        timestamp: FieldValue.serverTimestamp(),
        createdAt: new Date(),
        read: false,
        sentToTokens: 1,
        totalTokens: fcmTokens.length,
      };

      const notificationRef = await db.collection("notifications").add(notificationData);
      
      console.log(`✅ [TEST_FCM] Test notification sent and stored: ${notificationRef.id}`);

      return {
        success: true,
        message: "Test notification sent successfully",
        notificationId: notificationRef.id,
        sentToTokens: 1,
        totalTokens: fcmTokens.length,
      };

    } catch (error) {
      console.error("❌ [TEST_FCM] Error sending test notification:", error);
      throw new Error(`Test notification failed: ${error.message}`);
    }
  }
);

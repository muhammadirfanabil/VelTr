const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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
// FUNCTION 1: Process Driving History
// ===========================
exports.processdrivinghistory = onDocumentCreated(
  {
    document: "devices/{deviceId}/gps/{gpsId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const gpsData = event.data.data();
    const { deviceId } = event.params;

    console.log(`🛰️ Processing GPS data for device: ${deviceId}`);
    console.log("📍 GPS Data:", gpsData);

    // Simple test implementation
    return {
      success: true,
      message: `Processed GPS for device ${deviceId}`,
      timestamp: new Date().toISOString(),
    };
  }
);

// ===========================
// FUNCTION 2: Cleanup Driving History
// ===========================
exports.cleanupdrivinghistory = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "Asia/Jakarta",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log("🧹 Cleanup function triggered");
    return { message: "Cleanup completed" };
  }
);

// ===========================
// FUNCTION 3: Query Driving History
// ===========================
exports.querydrivinghistory = onCall(
  {
    region: "asia-southeast1",
  },
  async (request) => {
    if (!request.auth) {
      throw new Error("Authentication required");
    }

    console.log("📊 Query function called");
    return { message: "Query function working" };
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

    // Get user's FCM tokens
    const userDoc = await db.collection("users_information").doc(ownerId).get();
    if (!userDoc.exists) {
      console.log(`⚠️ [FCM] User not found: ${ownerId}`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) {
      console.log(`⚠️ [FCM] No FCM tokens found for user: ${ownerId}`);
      return;
    }

    // Prepare notification message
    const actionText = action === "ENTER" ? "entered" : "exited";
    const title = `Geofence Alert`;
    const body = `${deviceName} has ${actionText} ${geofenceName}`;

    // Prepare FCM payload
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "geofence_alert",
        deviceId: deviceId,
        deviceName: deviceName,
        geofenceName: geofenceName,
        action: action.toLowerCase(),
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        timestamp: timestamp.toISOString(),
      },
      android: {
        priority: "high",
        notification: {
          icon: "ic_notification",
          sound: "default",
          channelId: "geofence_alerts",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
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

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize the Firebase Admin SDK
admin.initializeApp();

/**
 * A callable Cloud Function to find a user by their email address.
 *
 * @param {functions.https.CallableRequest<{email: string}>} request The
 * request object from the client.
 * @returns {Promise<{uid: string, stageName: string} | null>} A promise that
 * resolves with the user's UID and stageName if found, or null if not found.
 */
export const findUserByEmail = functions.https.onCall(
  async (request: functions.https.CallableRequest<{email: string}>):
  Promise<{uid: string, stageName: string} | null> => {
    // 1. Security Check
    if (!request.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated.",
      );
    }

    // 2. Input Validation
    const email = request.data.email;
    if (!email || typeof email !== "string") {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "The function must be called with a valid 'email' argument.",
      );
    }

    try {
      // 3. Find the user in Firebase Authentication to get their UID.
      const userRecord = await admin.auth().getUserByEmail(email);

      // --- THIS IS THE NEW PART ---
      // 4. Use the UID to look up the user's document in Firestore.
      const userDoc =
        await admin.firestore().collection("users").doc(userRecord.uid).get();

      if (!userDoc.exists) {
        // This is an edge case where a user exists in Auth but not Firestore.
        functions.logger.warn(`User ${userRecord.uid} found in Auth but not in Firestore.`);
        return null;
      }

      const stageName = userDoc.data()?.stageName || "Unknown Stage Name";
      // --- END OF NEW PART ---

      // 5. The Response: Return both the UID and the stageName.
      return { uid: userRecord.uid, stageName: stageName };
    } catch (error: any) {
      if (error.code === "auth/user-not-found") {
        return null;
      }
      functions.logger.error("Error finding user by email:", error);
      throw new functions.https.HttpsError(
          "internal",
          "An unexpected error occurred.",
      );
    }
  });
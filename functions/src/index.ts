import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// --- THIS IS THE DEFINITIVE FIX ---
// Initialize the app at the global scope. The modern SDK ensures this is
// done efficiently and idempotently (it only runs once). This solves the
// cold start initialization race condition.
admin.initializeApp();
// --- END OF FIX ---

/**
 * A callable Cloud Function to find a user by their email address.
 */
export const findUserByEmail = functions.https.onCall(
  async (request: functions.https.CallableRequest<{email: string}>):
  Promise<{uid: string, stageName: string} | null> => {
    // No need for lazy initialization here anymore.

    if (!request.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated.",
      );
    }

    const email = request.data.email;
    if (!email || typeof email !== "string") {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "The function must be called with a valid 'email' argument.",
      );
    }

    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      const userDoc =
        await admin.firestore().collection("users").doc(userRecord.uid).get();

      if (!userDoc.exists) {
        functions.logger.warn(`User ${userRecord.uid} found in Auth but not in Firestore.`);
        return null;
      }

      const stageName = userDoc.data()?.stageName || "Unknown Stage Name";
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

/**
 * A callable Cloud Function to securely sign up for or remove a user from a spot.
 */
export const manageSpotSignup = functions.https.onCall(
  async (request: functions.https.CallableRequest<{listId: string, spotKey: string, action: 'signup' | 'remove'}>):
  Promise<{success: boolean, message: string}> => {
    // No need for lazy initialization here anymore.

    if (!request.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "You must be signed in to manage a spot.",
      );
    }

    const { listId, spotKey, action } = request.data;
    const uid = request.auth.uid;

    if (!listId || !spotKey || !action) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameters: listId, spotKey, or action.",
      );
    }

    const listRef = admin.firestore().collection("Lists").doc(listId);

    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const listDoc = await transaction.get(listRef);

        if (!listDoc.exists) {
          throw new functions.https.HttpsError("not-found", "This list does not exist.");
        }

        const listData = listDoc.data()!;
        const spots = listData.spots || {};
        const signedUpUserIds = listData.signedUpUserIds || [];

        if (action === 'signup') {
          if (spots[spotKey]) {
            throw new functions.https.HttpsError("already-exists", "This spot is already taken.");
          }
          if (signedUpUserIds.includes(uid)) {
            throw new functions.https.HttpsError("already-exists", "You are already signed up for another spot on this list.");
          }

          const userDoc = await admin.firestore().collection("users").doc(uid).get();
          if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Your user profile could not be found.");
          }
          const stageName = userDoc.data()?.stageName || "Unknown Performer";

          spots[spotKey] = { userId: uid, name: stageName, isOver: false };
          signedUpUserIds.push(uid);

          transaction.update(listRef, {
            spots: spots,
            signedUpUserIds: signedUpUserIds,
          });
        } else if (action === 'remove') {
          if (!spots[spotKey] || spots[spotKey].userId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "You do not have permission to remove this signup.");
          }

          delete spots[spotKey];
          const updatedSignedUpIds = signedUpUserIds.filter((id: string) => id !== uid);

          transaction.update(listRef, {
            spots: spots,
            signedUpUserIds: updatedSignedUpIds,
          });
        }
      });

      const message = action === 'signup' ? "You're on the list!" : "You've been removed from the list.";
      return { success: true, message: message };

    } catch (error: any) {
      functions.logger.error("Error in manageSpotSignup:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", "An unexpected error occurred.");
    }
  });
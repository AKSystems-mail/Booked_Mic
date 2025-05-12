// Import v2 specific modules
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2"; // v2 logger
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK ONCE
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

interface ManageSpotSignupData {
  listId: string;
  spotKey: string;
  action: "signup" | "remove";
}

export const manageSpotSignup = onCall(
  {
    // region: 'us-central1', // Example option
    // enforceAppCheck: true, // Recommended for production
  },
  async (request) => {
    if (!request.auth) {
      logger.error("Authentication failed: No auth context.");
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }
    const performerUid = request.auth.uid;
    const data = request.data as ManageSpotSignupData;
    const {listId, spotKey, action} = data;

    if (!listId || !spotKey || !action) {
      logger.error("Invalid argument: Missing parameters.", {data});
      throw new HttpsError(
        "invalid-argument",
        "Missing required parameters: listId, spotKey, or action."
      );
    }
    if (action !== "signup" && action !== "remove") {
      logger.error("Invalid argument: Invalid action.", {action});
      throw new HttpsError(
        "invalid-argument",
        "Invalid action. Must be 'signup' or 'remove'."
      );
    }

    const listDocRef = db.collection("Lists").doc(listId);
    const userProfileRef = db.collection("users").doc(performerUid);

    try {
      await db.runTransaction(async (transaction) => {
        const listDocSnapshot = await transaction.get(listDocRef);
        const userProfileSnapshot = await transaction.get(userProfileRef);

        if (!listDocSnapshot.exists) {
          logger.warn(`List not found: ${listId}`);
          throw new HttpsError(
            "not-found",
            `List with ID ${listId} not found.`
          );
        }

        const listData = listDocSnapshot.data() || {};
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const spots = (listData.spots || {}) as {[key: string]: any};
        const signedUpUserIds = (listData.signedUpUserIds || []) as string[];

        if (action === "signup") {
          if (!userProfileSnapshot.exists) {
            logger.warn(
              `User profile for UID: ${performerUid} not found. ` +
              "Using UID as fallback name."
            );
          }
          const userProfileData = userProfileSnapshot.data() || {};
          const performerStageName =
            userProfileData.stageName || userProfileData.name || performerUid;

          if (signedUpUserIds.includes(performerUid)) {
            logger.warn(
              `User ${performerUid} already signed up for list ${listId}.`
            );
            throw new HttpsError(
              "already-exists",
              "You are already signed up for a spot on this list."
            );
          }
          if (spots[spotKey] && spots[spotKey].userId != null) {
            logger.warn(`Spot ${spotKey} on list ${listId} already taken.`);
            throw new HttpsError(
              "already-exists",
              `Spot ${spotKey} is already taken.`
            );
          }

          const newSpotData = {
            userId: performerUid,
            name: performerStageName,
            isOver: false,
            signedUpAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          const newSpots = {...spots, [spotKey]: newSpotData};

          transaction.update(listDocRef, {
            spots: newSpots,
            signedUpUserIds: admin.firestore.FieldValue.arrayUnion(
              performerUid
            ),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          logger.info(
            `User ${performerUid} signed up for spot ${
              spotKey} on list ${listId}.`
          );
        } else if (action === "remove") {
          if (!spots[spotKey] || spots[spotKey].userId !== performerUid) {
            logger.warn(
              `User ${performerUid} attempted to remove from spot ${spotKey} ` +
              `on list ${listId} which they don't occupy.`
            );
            throw new HttpsError(
              "failed-precondition",
              "You are not signed up for this spot or the spot is empty."
            );
          }

          const newSpots = {...spots};
          delete newSpots[spotKey];

          transaction.update(listDocRef, {
            spots: newSpots,
            signedUpUserIds: admin.firestore.FieldValue.arrayRemove(
              performerUid
            ),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          logger.info(
            `User ${performerUid} removed from spot ${
              spotKey} on list ${listId}.`
          );
        }
      });

      return {
        success: true,
        message:
          action === "signup" ?
            "Successfully signed up!" :
            "Successfully removed from spot.",
      };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    } catch (error: any) {
      const logPayload = {
        listId,
        spotKey,
        action,
        performerUid,
        error: error.message || error.toString(),
        details: error.details,
      };
      logger.error("Transaction failed for manageSpotSignup:", logPayload);

      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        error.message || "An error occurred while managing your spot.",
        error.details
      );
    }
  }
);

// functions/src/index.ts

import { onDocumentUpdated } from "firebase-functions/v2/firestore"; // Import v2 trigger
import * as logger from "firebase-functions/logger"; // Import v2 logger
import * as admin from "firebase-admin";
// Removed problematic import: import { Change, QueryDocumentSnapshot } from "firebase-functions/v1/firestore";
// Import DocumentSnapshot from admin SDK if needed for explicit typing elsewhere, though often inferred
// import { DocumentSnapshot } from "firebase-admin/firestore";

// Initialize Firebase Admin SDK only once
admin.initializeApp();
// Removed unused variable: const db = admin.firestore();
const { FieldValue } = admin.firestore; // Keep FieldValue

/**
 * Triggered when a document in the 'Lists' collection is updated (v2 Syntax).
 * Handles shifting spots up when a main list spot is removed.
 */
export const onListUpdateShiftSpots = onDocumentUpdated(
  "Lists/{listId}",
  async (event): Promise<void> => { // Use inferred type for event
    // Ensure data exists for the event
    if (!event.data) {
      logger.info("No data associated with the event.");
      return;
    }

    const listId = event.params.listId;
    // beforeSnap and afterSnap will be correctly typed as DocumentSnapshot | undefined
    const beforeSnap = event.data.before;
    const afterSnap = event.data.after;

    // Ensure both snapshots exist (essential for comparing changes)
    if (!beforeSnap?.exists || !afterSnap?.exists) {
      logger.info(`[${listId}] Before or after snapshot missing or deleted.`);
      return; // Exit if one snapshot is missing
    }

    // beforeData and afterData will be inferred as DocumentData | undefined
    const beforeData = beforeSnap.data();
    const afterData = afterSnap.data();

    // Exit if crucial data is missing
    if (!beforeData || !afterData) {
      logger.info(`[${listId}] Missing data before or after.`);
      return;
    }

    const beforeSpots: { [key: string]: any } = beforeData.spots ?? {};
    const afterSpots: { [key: string]: any } = afterData.spots ?? {};
    const numberOfSpots: number = afterData.numberOfSpots ?? 0;
    const numberOfWaitlistSpots: number = afterData.numberOfWaitlistSpots ?? 0;

    // --- Detect if a MAIN list spot was removed ---
    let removedSpotNumber: number | null = null;
    for (let i = 1; i <= numberOfSpots; i++) {
      const key = i.toString();
      if (
        Object.prototype.hasOwnProperty.call(beforeSpots, key) &&
        beforeSpots[key] !== "RESERVED" &&
        !Object.prototype.hasOwnProperty.call(afterSpots, key)
      ) {
        removedSpotNumber = i;
        logger.info(`[${listId}] Detected removal of main spot: ${key}`);
        break;
      }
    }

    if (removedSpotNumber === null) {
      logger.info(`[${listId}] No main spot removal detected.`);
      return; // Exit if no main spot was removed
    }

    // --- Perform Shifts ---
    logger.info(`[${listId}] Starting shift process from spot ${removedSpotNumber}.`);
    const updates: { [key: string]: any } = {};
    let lastUpdatedMainKey = "";

    // 1. Shift main list spots up
    for (let i = removedSpotNumber; i < numberOfSpots; i++) {
      const currentKey = i.toString();
      const nextKey = (i + 1).toString();
      lastUpdatedMainKey = currentKey;

      if (Object.prototype.hasOwnProperty.call(afterSpots, nextKey)) {
        updates[`spots.${currentKey}`] = afterSpots[nextKey];
        logger.debug(`[${listId}] Shifting main: ${nextKey} -> ${currentKey}`);
      } else {
        updates[`spots.${currentKey}`] = FieldValue.delete();
        logger.debug(`[${listId}] Shifting main: ${currentKey} deleted (end)`);
        break;
      }
    }

    // 2. Promote first waitlist spot
    const firstWaitlistKey = "W1";
    // Determine the correct target spot key
    const targetMainSpotKey = (lastUpdatedMainKey && parseInt(lastUpdatedMainKey, 10) >= removedSpotNumber)
                               ? lastUpdatedMainKey // If main list shift happened, target is the last shifted key
                               : removedSpotNumber.toString(); // Otherwise, target is the originally removed spot

    if (
      numberOfSpots > 0 &&
      Object.prototype.hasOwnProperty.call(afterSpots, firstWaitlistKey)
    ) {
      updates[`spots.${targetMainSpotKey}`] = afterSpots[firstWaitlistKey];
      updates[`spots.${firstWaitlistKey}`] = FieldValue.delete();
      logger.debug(`[${listId}] Promoting waitlist: ${firstWaitlistKey} -> ${targetMainSpotKey}`);

      // 3. Shift remaining waitlist spots up
      for (let j = 1; j < numberOfWaitlistSpots; j++) {
        const currentWaitKey = `W${j}`;
        const nextWaitKey = `W${j + 1}`;

        if (Object.prototype.hasOwnProperty.call(afterSpots, nextWaitKey)) {
          updates[`spots.${currentWaitKey}`] = afterSpots[nextWaitKey];
          logger.debug(`[${listId}] Shifting waitlist: ${nextWaitKey} -> ${currentWaitKey}`);
        } else {
          updates[`spots.${currentWaitKey}`] = FieldValue.delete();
          logger.debug(`[${listId}] Shifting waitlist: ${currentWaitKey} deleted (end)`);
          break;
        }
      }
      // Ensure the last waitlist spot is cleared if it was moved up
      const lastWaitlistKey = `W${numberOfWaitlistSpots}`;
      // Check if the spot BEFORE the last one received an update in this batch OR if it was the only waitlist spot
      if (numberOfWaitlistSpots > 0 && (updates[`spots.W${numberOfWaitlistSpots - 1}`] !== undefined || numberOfWaitlistSpots === 1) ) {
         // Only delete if it wasn't already marked for deletion (e.g., if it was W1 and got promoted)
         if (`spots.${lastWaitlistKey}` !== `spots.${firstWaitlistKey}` || updates[`spots.${firstWaitlistKey}`] === undefined) {
             updates[`spots.${lastWaitlistKey}`] = FieldValue.delete();
         }
      }

    } else if (numberOfSpots > 0) {
      // No waitlist to promote, ensure the target main spot is cleared if needed
      // Only delete if it wasn't already marked for deletion by the main shift loop
      if (updates[`spots.${targetMainSpotKey}`] === undefined) {
         updates[`spots.${targetMainSpotKey}`] = FieldValue.delete();
         logger.debug(`[${listId}] No waitlist promotion, clearing target main spot: ${targetMainSpotKey}`);
      }
    }

    // --- Apply Updates ---
    if (Object.keys(updates).length > 0) {
      try {
        logger.info(`[${listId}] Applying ${Object.keys(updates).length} updates:`, updates);
        // Use afterSnap.ref which is the DocumentReference for v2
        await afterSnap.ref.update(updates);
        logger.info(`[${listId}] Spot shift update successful.`);
      } catch (error) {
        logger.error(`[${listId}] Error updating document after shift:`, error);
      }
    } else {
      logger.info(`[${listId}] No updates needed after analysis.`);
    }
    // Functions should return a Promise or null/undefined
    return;
  }
);
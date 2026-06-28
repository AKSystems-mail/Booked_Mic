// functions/src/index.ts

import { onDocumentUpdated } from "firebase-functions/v2/firestore"; // Import v2 trigger
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from "firebase-functions/logger"; // Import v2 logger
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK only once
admin.initializeApp();
const { FieldValue } = admin.firestore; // Keep FieldValue

function findUserSpotKey(spots: { [key: string]: any }, userId: string): string | null {
  for (const [key, value] of Object.entries(spots)) {
    if (typeof value === 'object' && value !== null && value.userId === userId) {
      return key;
    }
  }
  return null;
}

/**
 * Counts active (non-isOver) performers ahead of a given spot key.
 * Handles both numeric main-list keys ("1", "2") and waitlist keys ("W1", "W2").
 */
function countActiveAhead(spots: { [key: string]: any }, targetKey: string): number {
  const targetNum = targetKey.startsWith('W')
    ? parseInt(targetKey.substring(1)) + 100000
    : parseInt(targetKey);
  let count = 0;
  for (const [key, value] of Object.entries(spots)) {
    // Must have a non-empty name (matches Flutter-side counting logic)
    if (typeof value !== 'object' || value === null) continue;
    const name = value.name;
    if (typeof name !== 'string' || name.trim().length === 0) continue;
    const thisNum = key.startsWith('W')
      ? parseInt(key.substring(1)) + 100000
      : parseInt(key);
    if (!isNaN(thisNum) && !isNaN(targetNum) && thisNum < targetNum && !value.isOver) {
      count++;
    }
  }
  return count;
}

/**
 * Finds a user's UID by their Host Code.
 */
export const findUserByHostCode = onCall(async (request) => {
  const code = request.data.hostCode;
  if (!code || typeof code !== 'string') {
    throw new HttpsError('invalid-argument', 'The function must be called with a valid Host Code.');
  }

  try {
    const querySnapshot = await admin.firestore()
      .collection("users")
      .where("hostCode", "==", code)
      .limit(1)
      .get();

    if (querySnapshot.empty) {
      throw new HttpsError('not-found', 'No user found with that Host Code.');
    }

    return { uid: querySnapshot.docs[0].id };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error('Error fetching user by host code:', error);
    throw new HttpsError('internal', 'Internal error fetching user.');
  }
});

/**
 * Finds a user's UID by their email address.
 */
export const findUserByEmail = onCall(async (request) => {
  const email = request.data.email;
  if (!email || typeof email !== 'string') {
    throw new HttpsError('invalid-argument', 'The function must be called with a valid email.');
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    return { uid: userRecord.uid };
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'No user found with that email.');
    }
    logger.error('Error fetching user by email:', error);
    throw new HttpsError('internal', 'Internal error fetching user.');
  }
});

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
      // --- NOT isOver removal path (no main list spot was deleted, so either
      //     an isOver transition or a reorder) ---

      // Terminology used throughout:
      //   Spot Key   — Firestore string key ("1", "2", "W1"), NOT a 0‑based index
      //   Ahead Count — Number of ACTIVE (non‑isOver) performers with a lower
      //                 Spot Key than yours. INCLUDES the person on stage.
      //                 Spot 1 → Ahead Count 0 (On Stage)
      //                 Spot 2 → Ahead Count 1 (Up Next)
      //                 Spot N → Ahead Count N‑1
      //   Advance    — Your Ahead Count decreases because someone ahead was
      //                Marked Over
      //   Mark Over  — Setting isOver=true on a performer's spot
      //   Position Notification — Local/FCM telling a performer they Advanced

      // --- Detect isOver transition: active performer → Marked Over ---
      // NOTE: We do NOT send an FCM to the performer being Marked Over.
      // The performer on stage (Ahead Count 0) doesn't need a "Your set is
      // over!" message — they're performing, they already know.
      // We DO notify remaining performers whose position improved (below).
      for (const [key, newValue] of Object.entries(afterSpots)) {
        // Must have either userId (for FCM notification) or isOver=True (for a
        // spot that was marked over but lacks userId — e.g. host-code signups).
        if (typeof newValue === 'object' && newValue !== null && (newValue.isOver === true || ('userId' in newValue && newValue.userId))) {
          if (newValue.isOver === true) {
            const oldValue = beforeSpots[key];
            const wasOver = typeof oldValue === 'object' && oldValue !== null && oldValue.isOver === true;
            if (!wasOver) {
              // isOver transition confirmed — no FCM to the over performer.
              // Fall through to notify remaining performers.

              // --- Notify remaining performers whose Ahead Count decreased ---
              for (const [otherKey, otherValue] of Object.entries(afterSpots)) {
                if (otherKey === key) continue;
                if (typeof otherValue !== 'object' || otherValue === null || !otherValue.userId) continue;
                if (otherValue.isOver === true) continue;

                const oldAhead = countActiveAhead(beforeSpots, otherKey);
                const newAhead = countActiveAhead(afterSpots, otherKey);

                if (newAhead < oldAhead) {
                  const otherUserId: string = otherValue.userId;
                  // Stage (ahead 0) gets no notification — performer is live.
                  // Ahead 1+ gets FCM push (Flutter local notification may not
                  // fire when the app is backgrounded / listener suspended).
                  if (newAhead <= 0) {
                    const stageLabel = newAhead === 0 ? 'stage' : 'up_next';
                    logger.info(`[${listId}] Performer ${otherUserId} (${otherKey}) reached ${stageLabel} — no FCM needed`);
                    continue;
                  }
                  try {
                    const otherUserDoc = await admin.firestore().collection("users").doc(otherUserId).get();
                    const otherTokens = otherUserDoc.data()?.fcmTokens as string[] | undefined;
                    if (otherTokens && otherTokens.length > 0) {
                      const body = `${newAhead} ahead of you.`;
                      await admin.messaging().sendEachForMulticast({
                        data: {
                          type: "spot_update",
                          title: "Booked Mic Update",
                          body: body,
                          listId: listId,
                          spot: otherKey,
                        },
                        tokens: otherTokens,
                      });
                      logger.info(`[${listId}] Notified remaining performer ${otherUserId} (${otherKey}) — position improved ${oldAhead}→${newAhead}`);
                    }
                  } catch (otherNotifError) {
                    logger.error(`[${listId}] Error notifying remaining performer ${otherUserId}:`, otherNotifError);
                  }
                }
              }
            }
          }
        }
      }

      // --- Reorder detection: a performer's Spot Key changed without removal ---
      // When someone reorders themselves, the Ahead Count for all intervening
      // performers changes. We send a Position Notification to everyone affected
      // so they know their new spot.
      const reorderNotifications: Array<{ userId: string; newKey: string }> = [];
      for (const [newKey, newValue] of Object.entries(afterSpots)) {
        if (typeof newValue === 'object' && newValue !== null && 'userId' in newValue) {
          const oldKey = findUserSpotKey(beforeSpots, newValue.userId);
          if (oldKey !== null && oldKey !== newKey) {
            reorderNotifications.push({ userId: newValue.userId, newKey });
          }
        }
      }
      if (reorderNotifications.length > 0) {
        logger.info(`[${listId}] Detected reorder for ${reorderNotifications.length} performers.`);
        for (const { userId, newKey } of reorderNotifications) {
          try {
            const userDoc = await admin.firestore().collection("users").doc(userId).get();
            const fcmTokens = userDoc.data()?.fcmTokens as string[] | undefined;
            if (fcmTokens && fcmTokens.length > 0) {
              // Stage (spot 1) gets no notification — performer is live.
              // Up next (spot 2) handled by Flutter local notification.
              // Skip FCM for both to avoid unwanted popups.
              if (newKey === "1" || newKey === "2") {
                const stageLabel = newKey === "1" ? 'stage' : 'up_next';
                logger.info(`[${listId}] Reorder moved ${userId} to ${stageLabel} — no FCM needed`);
                continue;
              }
              const body = `Moved to spot #${newKey}`;
              await admin.messaging().sendEachForMulticast({
                data: {
                  type: "spot_update",
                  title: "Booked Mic Update",
                  body: body,
                  listId: listId,
                  spot: newKey,
                },
                tokens: fcmTokens,
              });
              logger.info(`[${listId}] Notified user ${userId} about reorder to ${newKey}`);
            }
          } catch (notifError) {
            logger.error(`[${listId}] Error notifying user ${userId}:`, notifError);
          }
        }
      } else {
        logger.info(`[${listId}] No main spot removal or reorder detected.`);
      }
      return;
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
        logger.info(`[${listId}] Applying ${Object.keys(updates).length} updates.`);
        await afterSnap.ref.update(updates);

        // --- Notify Performers of Shifts: send FCM for every spot reassigned ---
        // These are Advanced performers whose Spot Key changed via waitlist
        // promotion or reorder — they get a Position Notification with their
        // new spot and Ahead Count.
        for (const [key, value] of Object.entries(updates)) {
          // If the update affected a spot
          if (key.startsWith("spots.") && key !== "spots." && typeof value === 'object' && value !== null && 'userId' in value) {
            const userId = value.userId;
            const spotKey = key.replace("spots.", "");
            
            // Look up user tokens
            const userDoc = await admin.firestore().collection("users").doc(userId).get();
            const fcmTokens = userDoc.data()?.fcmTokens as string[] | undefined;
            
            if (fcmTokens && fcmTokens.length > 0) {
              // Stage (spot 1) gets no notification — performer is live.
              // Up next (spot 2) handled by Flutter local notification.
              // Skip FCM for both to avoid unwanted popups.
              if (spotKey === "1" || spotKey === "2") {
                const stageLabel = spotKey === "1" ? 'stage' : 'up_next';
                logger.info(`[${listId}] Shift moved ${userId} to ${stageLabel} — no FCM needed`);
                continue;
              }
              const body = `Moved to spot #${spotKey} • ${parseInt(spotKey) - 1} ahead of you.`;
              
              await admin.messaging().sendEachForMulticast({
                data: {
                  type: "spot_update",
                  title: "Booked Mic Update",
                  body: body,
                  listId: listId,
                  spot: spotKey,
                },
                tokens: fcmTokens,
              });
              logger.info(`[${listId}] Notified user ${userId} about shift to ${spotKey}`);
            }
          }
        }
        logger.info(`[${listId}] Spot shift update and notifications successful.`);
      } catch (error) {
        logger.error(`[${listId}] Error updating document or sending notifications:`, error);
      }
    } else {
      logger.info(`[${listId}] No updates needed after analysis.`);
    }
    return;
  }
);

// Callable function to atomically allocate a unique 6-digit host code.
export const allocateHostCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Request must be authenticated.');
  }

  const db = admin.firestore();
  const hostCodesColl = db.collection('hostCodes');
  const maxAttempts = 10;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const code = (Math.floor(100000 + Math.random() * 900000)).toString();
    const codeDocRef = hostCodesColl.doc(code);
    const userDocRef = db.collection('users').doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const codeSnap = await transaction.get(codeDocRef);
        if (codeSnap.exists) {
          // Signal a collision to outer loop
          throw 'ALREADY_EXISTS';
        }
        // Reserve the code and write it to the user's profile atomically
        transaction.set(codeDocRef, { uid: uid, createdAt: FieldValue.serverTimestamp() });
        transaction.set(userDocRef, { hostCode: code, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      });

      // If transaction succeeded, return the code
      return { hostCode: code };
    } catch (err: any) {
      if (err === 'ALREADY_EXISTS') {
        // try again
        logger.debug(`Host code collision on ${code}, retrying...`);
        continue;
      }
      logger.error('Error allocating host code transactionally:', err);
      throw new HttpsError('internal', 'Error allocating host code.');
    }
  }

  throw new HttpsError('resource-exhausted', 'Unable to generate unique host code after multiple attempts.');
});

// Scheduled cleanup: delete client_logs older than 7 days
export const clearOldClientLogs = onSchedule('every 24 hours', async (_event) => {
  const cutoffMillis = Date.now() - 1000 * 60 * 60 * 24 * 7; // 7 days
  const cutoff = admin.firestore.Timestamp.fromMillis(cutoffMillis);
  const db = admin.firestore();
  try {
    const snapshot = await db.collection('client_logs').where('timestamp', '<', cutoff).limit(500).get();
    if (snapshot.empty) {
      logger.info('clearOldClientLogs: no logs to delete');
      return;
    }
    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    logger.info(`clearOldClientLogs: deleted ${snapshot.size} documents`);
  } catch (e) {
    logger.error('clearOldClientLogs failed', e);
  }
});
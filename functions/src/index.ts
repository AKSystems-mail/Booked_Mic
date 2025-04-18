import {onDocumentDeleted, FirestoreEvent}
  from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger"; // Import v2 logger
import * as admin from "firebase-admin";
import {QueryDocumentSnapshot} from "firebase-functions/v1/firestore";

// Initialize Firebase Admin SDK only once
admin.initializeApp();
// const db = admin.firestore(); // Not strictly needed if using snap.ref

const BATCH_SIZE = 100; // How many docs to delete per batch

/**
 * Triggered when a document in the 'Lists' collection is deleted (v2 Syntax).
 * Clears the 'bucketSignups' subcollection.
 */
export const onListDeleteClearBucket = onDocumentDeleted(
  "Lists/{listId}",
  async (
    event: FirestoreEvent<QueryDocumentSnapshot | undefined, { listId: string }>
  ): Promise<void> => {
    // The event.data for onDelete contains the snapshot *before* deletion
    if (!event.data) {
      logger.info("No data associated with the delete event (might be error).");
      return;
    }

    const listId = event.params.listId;
    // Use event.data.ref which points to the deleted document's reference
    const listRef = event.data.ref;
    const bucketPath = `${listRef.path}/bucketSignups`; // Build path using ref

    logger.info(`List ${listId} 
        deleted. Clearing subcollection: ${bucketPath}`);

    const bucketRef = admin.firestore().collection(bucketPath);

    try {
      let query = bucketRef.orderBy(admin.firestore.FieldPath.documentId()).
        limit(BATCH_SIZE);
      let snapshot = await query.get();

      // When there are no documents left, we are done
      while (snapshot.size > 0) {
        const batch = admin.firestore().batch();
        snapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        // Commit the batch
        await batch.commit();
        logger.info(`Deleted ${snapshot.size} 
            bucket signups for list ${listId}`);

        // Check if we need to fetch more
        if (snapshot.size < BATCH_SIZE) {
          break; // Less than batch size means we got all remaining docs
        }

        // Get the last document deleted to paginate
        const lastVisible = snapshot.docs[snapshot.docs.length - 1];

        // Construct a new query starting after the last deleted document
        query = bucketRef.orderBy(admin.firestore.FieldPath.documentId())
          .startAfter(lastVisible).limit(BATCH_SIZE);
        snapshot = await query.get();
      }
      logger.info(`Finished clearing bucketSignups for list ${listId}`);
    } catch (error) {
      logger.error(`Error clearing bucketSignups for list ${listId}:`, error);
    }
    return; // Explicit return for Promise<void>
  }
);

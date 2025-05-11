// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists';
  // Removed unused _userCollection

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async {
    // Added return type
    Map<String, dynamic> showData = show.toMap();
    showData['userId'] = show.userId;
    showData['spots'] = {};
    showData['signedUpUserIds'] = [];
    showData['createdAt'] = FieldValue.serverTimestamp();
    showData.remove('id');
    DocumentReference docRef =
        await _db.collection(_listCollection).add(showData);
    return docRef.id; // Added return
  }

  Future<void> updateShow(
      String listId, Map<String, dynamic> updateData) async {
    // Ensure sensitive fields are not accidentally included if map comes directly from UI
    updateData.remove('userId');
    updateData.remove('createdAt');
    updateData.remove('spots');
    updateData.remove('signedUpUserIds');
    updateData.remove('id');
    updateData
        .remove('qrCodeData'); // Should qrCodeData be updatable? Probably not.

    // Remove null values unless explicitly allowed (like coordinates)
    updateData.removeWhere((key, value) =>
        value == null && key != 'latitude' && key != 'longitude');

    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() {
    return _db
        .collection(_listCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String listId) {
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
      if (!doc.exists) throw Exception("List with ID $listId not found.");
      return Show.fromFirestore(doc);
    });
  }


  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    final docRef = _db.collection(_listCollection).doc(listId);
    try {
      await _db.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return;
        final spotsMap =
            (docSnap.data()?['spots'] as Map<String, dynamic>?) ?? {};
        final spotData = spotsMap[spotKey];
        String? userIdToRemove;
        if (spotData is Map && spotData['userId'] != null) {
          userIdToRemove = spotData['userId'];
        }
        Map<String, dynamic> updates = {'spots.$spotKey': FieldValue.delete()};
        if (userIdToRemove != null) {
          updates['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
        }
        transaction.update(docRef, updates);
      });
    } catch (e) {
      print("Error removing performer from spot $spotKey: $e");
      rethrow;
    }
  }

  // --- *** ENSURE THIS METHOD EXISTS *** ---
  Future<void> updateSpotsMap(
      String listId, Map<String, dynamic> newSpotsMap) async {
    try {
      await _db
          .collection(_listCollection)
          .doc(listId)
          .update({'spots': newSpotsMap});
      print(
          "FirestoreService: Successfully updated spots map for list $listId");
    } catch (e) {
      print("FirestoreService: Error updating spots map for list $listId: $e");
      rethrow;
    }
  }

  // --- Ensure this method exists and uses correct collection/doc ---
  Future<void> deleteList(String listId) async {
    try {
      await _db.collection(_listCollection).doc(listId).delete();
      print("FirestoreService: Successfully deleted list $listId"); // Add log
    } catch (e) {
      print("FirestoreService: Error deleting list $listId: $e"); // Add log
      rethrow;
    }
  }

  Future<void> resetListSpots(String listId) async {
    final listRef = _db.collection(_listCollection).doc(listId);
    final bucketSignupsRef = listRef.collection('bucketSignups');

    try {
      // 1. Delete all documents in the bucketSignups subcollection
      // Fetch docs in batches to avoid memory issues if list is huge
      QuerySnapshot snapshot;
      do {
        snapshot = await bucketSignupsRef.limit(100).get(); // Get up to 100 docs
        if (snapshot.docs.isNotEmpty) {
          WriteBatch batch = _db.batch();
          for (DocumentSnapshot doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit(); // Commit the batch delete
        }
      } while (snapshot.docs.isNotEmpty); // Continue until subcollection is empty

      // 2. Update the main document to clear spots and signedUpUserIds
      await listRef.update({
        'spots': {},
        'signedUpUserIds': [],
      });

      print("Successfully reset spots and cleared bucket for list $listId");

    } catch (e) {
      print("Error resetting spots/bucket for list $listId: $e");
      rethrow;
    }
  }
  
  Stream<int> getBucketSignupCountStream(String listId) {
    return _db.collection(_listCollection).doc(listId)
              .collection('bucketSignups')
              .snapshots()
              .map((snapshot) => snapshot.size); // Map snapshot to size (count)
  }

  // In FirestoreService class

Future<List<QueryDocumentSnapshot>> getBucketSignups(String listId) async {
  try {
    final QuerySnapshot snapshot = await _db
        .collection(_listCollection)
        .doc(listId)
        .collection('bucketSignups')
        .get();
    return snapshot.docs;
  } catch (e) {
    // print("Error fetching bucket signups for list $listId: $e");
    rethrow;
  }
}

// In FirestoreService class

Future<Map<String, dynamic>?> drawAndAssignBucketSpot(String listId, String bucketSpotKey) async {
  final List<QueryDocumentSnapshot> bucketDocs = await getBucketSignups(listId);

  if (bucketDocs.isEmpty) {
    // print("Bucket is empty for list $listId. Cannot draw.");
    return null; // Or throw an exception: throw Exception('Bucket is empty.');
  }

  // Randomly select a performer
  final random = Random();
  final selectedDoc = bucketDocs[random.nextInt(bucketDocs.length)];
  final selectedPerformerData = selectedDoc.data() as Map<String, dynamic>?;

  if (selectedPerformerData == null || 
      selectedPerformerData['userId'] == null || 
      selectedPerformerData['stageName'] == null) {
    // print("Selected bucket document has invalid data: ${selectedDoc.id}");
    throw Exception('Selected bucket performer has invalid data.');
  }

  final String performerUserId = selectedPerformerData['userId'];
  final String performerName = selectedPerformerData['stageName'];

  // Prepare data for the spot
  final Map<String, dynamic> spotData = {
    'userId': performerUserId,
    'name': performerName,
    // 'timestamp': FieldValue.serverTimestamp(), // Optional: if you want to track when they were added
  };

  try {
    WriteBatch batch = _db.batch();

    // 1. Update the main list document with the drawn performer for the specific bucket spot
    DocumentReference listDocRef = _db.collection(_listCollection).doc(listId);
    batch.update(listDocRef, {'spots.$bucketSpotKey': spotData});

    // 2. Remove the drawn performer from the bucketSignups subcollection
    DocumentReference bucketSignupDocRef = _db
        .collection(_listCollection)
        .doc(listId)
        .collection('bucketSignups')
        .doc(performerUserId); // Assuming doc ID is the userId
    batch.delete(bucketSignupDocRef);

    await batch.commit();
    // print("Successfully drew $performerName ($performerUserId) for spot $bucketSpotKey and removed from bucket.");
    return spotData; // Return the data of the assigned spot
  } catch (e) {
    // print("Error during drawAndAssignBucketSpot transaction for list $listId: $e");
    rethrow;
  }
}

  // Check if a specific user is in the bucket
  Future<bool> isUserInBucket(String listId, String userId) async {
     try {
        final doc = await _db.collection(_listCollection).doc(listId)
                         .collection('bucketSignups').doc(userId).get();
        return doc.exists;
     } catch (e) {
        print("Error checking user in bucket: $e");
        return false; // Assume not in bucket on error
     }
  }

  // Add user to bucket
  Future<void> addUserToBucket(String listId, String userId, String stageName) async {
     try {
        await _db.collection(_listCollection).doc(listId)
                 .collection('bucketSignups').doc(userId) // Use userId as doc ID
                 .set({
                    'userId': userId,
                    'stageName': stageName,
                    'timestamp': FieldValue.serverTimestamp(),
                 });
     } catch (e) { print("Error adding user to bucket: $e"); rethrow; }
  }

  // Remove user from bucket
  Future<void> removeUserFromBucket(String listId, String userId) async {
     try {
        await _db.collection(_listCollection).doc(listId)
                 .collection('bucketSignups').doc(userId).delete();
     } catch (e) { print("Error removing user from bucket: $e"); rethrow; }
  }
  // In FirestoreService class
  // --- ADD Method to get bucket count ---
  Future<int> getBucketSignupCount(String listId) async {
    try {
      final snapshot = await _db
          .collection(_listCollection)
          .doc(listId)
          .collection('bucketSignups')
          .count() // Use Firestore aggregate count
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print("Error getting bucket signup count for list $listId: $e");
      return 0; // Return 0 on error
    }
  }


  Future<void> addManualNameToSpot(
      String listId, String spotKey, String name) async {
    try {
      await _db.collection(_listCollection).doc(listId).update({
        'spots.$spotKey': {
          // Use dot notation to update a specific key in the map
          'name': name,
          'isOver': false, // Default to not over when manually adding
          // Add other fields if necessary (e.g., userId: null if it's a manual add)
        }
      });
    } catch (e) {
      print(
          "FirestoreService: Error adding manual name to spot $spotKey for list $listId: $e");
      rethrow; // Rethrow to allow the provider/UI to handle it
    }
  }



  // --- Spot Map Manipulation Methods ---
// In FirestoreService class

  Future<void> setSpotOver(
      String listId, String spotKey, bool isOver, String performerId) async {
    try {
      DocumentReference listRef = _db.collection(_listCollection).doc(listId);

      // Update the spot data to set 'isOver'
      Map<String, dynamic> updateData = {
        'spots.$spotKey.isOver': isOver,
      };

      // If isOver is false and we have a performerId, set the performer name to "Reserved"
      if (!isOver && performerId.isNotEmpty) {
        updateData['spots.$spotKey.name'] = 'Reserved';
      }

      // Perform the update
      await listRef.update(updateData);
    } catch (e) {
      print(
          "FirestoreService: Error setting spot $spotKey to over for list $listId: $e");
      rethrow; // Rethrow for the provider/UI
    }
  }
}

// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';


class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists'; // Standardize collection name

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async { // Return the new document ID
    Map<String, dynamic> showData = show.toMap();
    // Ensure critical fields are initialized correctly, overriding toMap if needed
    showData['userId'] = show.userId; // Ensure userId from model is used
    showData['spots'] = {}; // Start with empty map
    showData['signedUpUserIds'] = []; // Start with empty array
    showData['createdAt'] = FieldValue.serverTimestamp(); // Set creation time

    // Remove fields that shouldn't be set on create from the model's map
    showData.remove('id'); // ID is auto-generated
    // createdAt is set above

    DocumentReference docRef = await _db.collection(_listCollection).add(showData);
    return docRef.id; // Return the ID
  }

  Future<void> updateShow(String listId, Show show) async {
    // Prepare map with ONLY the fields hosts are allowed to edit
    Map<String, dynamic> updateData = {
      'listName': show.showName,
      'address': show.address,
      'state': show.state,
      'date': Timestamp.fromDate(show.date), // Ensure it's a Timestamp
      'latitude': show.latitude, // Use null if not provided
      'longitude': show.longitude, // Use null if not provided
      'numberOfSpots': show.numberOfSpots,
      'numberOfWaitlistSpots': show.numberOfWaitlistSpots,
      'numberOfBucketSpots': show.numberOfBucketSpots,
      // Add other editable fields from your Show model if necessary
      // e.g., 'bucketSpots': show.bucketSpots,
    };
    // Remove null values to avoid overwriting existing fields with null
    updateData.removeWhere((key, value) => value == null);

    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() {
    return _db.collection(_listCollection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String listId) {
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
       if (!doc.exists) throw Exception("List with ID $listId not found.");
       return Show.fromFirestore(doc);
    });
  }

  // --- Spot Map Manipulation Methods ---

  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async {
     try {
        await _db.collection(_listCollection).doc(listId).update({
           'spots.$spotKey.isOver': isOver
        });
        print("Successfully set spot $spotKey to over: $isOver");
     } catch (e) { print("Error setting spot $spotKey over: $e"); rethrow; }
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
     try {
        final spotData = {'name': name, 'isOver': false}; // No userId for manual add
        await _db.collection(_listCollection).doc(listId).update({
           'spots.$spotKey': spotData
        });
        print("Successfully added manual name '$name' to spot $spotKey");
     } catch (e) { print("Error adding manual name to spot $spotKey: $e"); rethrow; }
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    try {
      final docSnap = await _db.collection(_listCollection).doc(listId).get();
      if (!docSnap.exists) return; // List doesn't exist

      final spotsMap = (docSnap.data()?['spots'] as Map<String, dynamic>?) ?? {};
      final spotData = spotsMap[spotKey];
      String? userIdToRemove;
      if (spotData is Map && spotData['userId'] != null) {
         userIdToRemove = spotData['userId'];
      }

      Map<String, dynamic> updates = {
         'spots.$spotKey': FieldValue.delete()
      };
      if (userIdToRemove != null) {
         updates['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
      }

      await _db.collection(_listCollection).doc(listId).update(updates);
      print("Successfully removed spot $spotKey");
      // Cloud function handles shifting
    } catch (e) { print("Error removing performer from spot $spotKey: $e"); rethrow; }
  }

  // --- *** NEW: Method to save the entire reordered spots map *** ---
  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async {
     try {
        await _db.collection(_listCollection).doc(listId).update({
           'spots': newSpotsMap
           // Note: We don't update signedUpUserIds here, as reordering doesn't change who is signed up
        });
        print("Successfully updated spots map for list $listId");
     } catch (e) {
        print("Error updating spots map for list $listId: $e");
        rethrow;
     }
  }
  // --- *** END NEW METHOD *** ---


 }

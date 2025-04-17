// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';

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
    try {
      // Update the document to set spots to empty map and signedUpUserIds to empty array
      await _db.collection(_listCollection).doc(listId).update({
        'spots': {}, // Clear the spots map
        'signedUpUserIds': [], // Clear the user IDs array
      });
      print("Successfully reset spots for list $listId");
    } catch (e) {
      print("Error resetting spots for list $listId: $e");
      rethrow; // Rethrow error
    }
  }
  
  // In FirestoreService class

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

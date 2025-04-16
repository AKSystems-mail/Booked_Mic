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

  Future<void> updateShow(
      String listId, Map<String, dynamic> updateData) async {
    // Changed to accept Map
    updateData.removeWhere((key, value) =>
        value == null && key != 'latitude' && key != 'longitude');
    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

    // In FirestoreService class

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    try {
      await _db.collection(_listCollection).doc(listId).update({
        'spots.$spotKey': { // Use dot notation to update a specific key in the map
          'name': name,
          'isOver': false, // Default to not over when manually adding
          // Add other fields if necessary (e.g., userId: null if it's a manual add)
        }
      });
    } catch (e) {
      print("FirestoreService: Error adding manual name to spot $spotKey for list $listId: $e");
      rethrow; // Rethrow to allow the provider/UI to handle it
    }
  }


  Stream<List<Show>> getShows() {
    // Added return type
    return _db
        .collection(_listCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Show.fromFirestore(doc))
            .toList()); // Added return
  }

  Stream<Show> getShow(String listId) {
    // Added return type
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
      if (!doc.exists) throw Exception("List with ID $listId not found.");
      return Show.fromFirestore(doc); // Added return
    });
  }

  // --- Spot Map Manipulation Methods ---
// In FirestoreService class

  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
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
      print("FirestoreService: Error setting spot $spotKey to over for list $listId: $e");
      rethrow; // Rethrow for the provider/UI
    }
  }


  // In FirestoreService class

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    try {
      // Get the document reference
      DocumentReference listRef = _db.collection(_listCollection).doc(listId);

      // Get the current spots map to find the userId to remove from the array
      DocumentSnapshot listSnap = await listRef.get();
      if (!listSnap.exists || listSnap.data() == null) {
         print("FirestoreService: List $listId not found for removal.");
         return; // Or throw an error
      }
      Map<String, dynamic> listData = listSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> spots = Map<String, dynamic>.from(listData['spots'] ?? {});
      String? userIdToRemove;
      if (spots.containsKey(spotKey) && spots[spotKey] is Map) {
         userIdToRemove = (spots[spotKey] as Map<String, dynamic>)['userId'];
      }

      // Prepare the update data
      Map<String, dynamic> updateData = {
        'spots.$spotKey': FieldValue.delete(), // Delete the key from the spots map
      };
      // Only try to remove the user ID if we found one
      if (userIdToRemove != null) {
        updateData['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
      }

      // Perform the update
      await listRef.update(updateData);

    } catch (e) {
      print("FirestoreService: Error removing performer from spot $spotKey for list $listId: $e");
      rethrow; // Rethrow for the provider/UI
    }
  }

  }
  Future<void> updateSpotsMap(
      String listId, Map<String, dynamic> newSpotsMap) async {/* ... */}

  // --- Remove City/Performer methods if unused ---


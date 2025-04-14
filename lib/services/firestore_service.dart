// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
// Assuming other models are not needed based on previous cleanup
// import 'package:myapp/models/performer.dart';
// import 'package:myapp/models/city.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists';
  final String _userCollection = 'users'; // Keep if user methods needed

  // --- List/Show Methods ---
  Future<String> createShow(Show show) async { /* ... */ }
  Future<void> updateShow(String listId, Show show) async { /* ... */ }
  Stream<List<Show>> getShows() { /* ... */ }
  Stream<Show> getShow(String listId) { /* ... */ }

  // --- Spot Map Manipulation Methods ---

  // --- MODIFIED setSpotOver ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
     try {
        // Prepare updates
        Map<String, dynamic> updates = {
           'spots.$spotKey.isOver': isOver
        };
        // Also remove user from signup array if marking as over
        if (isOver && performerId.isNotEmpty) {
           updates['signedUpUserIds'] = FieldValue.arrayRemove([performerId]);
           print("Removing $performerId from signedUpUserIds as they are set over.");
        } else if (!isOver && performerId.isNotEmpty) {
           // Optional: If you add functionality to UNSET 'isOver', you might
           // want to re-add the user ID here using FieldValue.arrayUnion.
           // For now, we only handle setting 'isOver' to true.
        }

        await _db.collection(_listCollection).doc(listId).update(updates);
        print("Successfully set spot $spotKey to over: $isOver");
     } catch (e) {
        print("Error setting spot $spotKey over: $e");
        rethrow;
     }
  }
  // --- END MODIFICATION ---

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... (Already handles arrayRemove) ... */ }
  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }
  Future<void> deleteList(String listId) async { /* ... */ } // Keep delete method

  // --- Remove City/Performer methods if unused ---
}
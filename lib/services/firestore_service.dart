// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
// ... other imports if needed ...

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists';
  // final String _userCollection = 'users';

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async { /* ... */ }
  Future<void> updateShow(String listId, Show show) async { /* ... */ }
  Stream<List<Show>> getShows() { /* ... */ }
  Stream<Show> getShow(String listId) { /* ... */ }

  // --- Spot Map Manipulation Methods ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async { /* ... */ }
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... */ }
  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }

  // --- *** ADD DELETE LIST METHOD *** ---
  Future<void> deleteList(String listId) async {
     try {
        await _db.collection(_listCollection).doc(listId).delete();
        print("Successfully deleted list $listId");
     } catch (e) {
        print("Error deleting list $listId: $e");
        rethrow; // Rethrow error to be caught by provider/UI
     }
  }
  // --- *** END ADD DELETE LIST METHOD *** ---


  // --- Remove City/Performer methods if unused ---
  // ...
}

// --- Dummy Models (Remove if you have real ones) ---
// ...
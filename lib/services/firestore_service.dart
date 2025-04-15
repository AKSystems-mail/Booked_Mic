// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
// Removed unused models

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists';
  // Removed unused _userCollection

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async { // Added return type
    // ... (logic) ...
    DocumentReference docRef = await _db.collection(_listCollection).add(show.toMap());
    return docRef.id; // Added return
  }

  Future<void> updateShow(String listId, Map<String, dynamic> updateData) async { // Changed to accept Map
    // Remove null values carefully
    updateData.removeWhere((key, value) => value == null && key != 'latitude' && key != 'longitude');
    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() { // Added return type
    return _db.collection(_listCollection).orderBy('createdAt', descending: true)
           .snapshots().map((snapshot) =>
              snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList()); // Added return
  }

  Stream<Show> getShow(String listId) { // Added return type
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
       if (!doc.exists) throw Exception("List with ID $listId not found.");
       return Show.fromFirestore(doc); // Added return
    });
  }

  // --- Spot Map Manipulation Methods ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async { /* ... */ }
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... */ }
  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }
  Future<void> deleteList(String listId) async { /* ... */ }

  // --- Remove City/Performer methods if unused ---
}
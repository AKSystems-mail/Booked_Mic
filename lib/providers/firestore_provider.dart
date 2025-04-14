// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
// ... other model imports if needed ...

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() { /* ... */ }
  Stream<Show> getShow(String listId) { /* ... */ }
  Future<String> createShow(Show show) async { /* ... */ }
  Future<void> updateShow(String listId, Show show) async { /* ... */ }

  // --- Spot Manipulation Methods (Key-based) ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async { /* ... */ }
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... */ }
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }

  // --- *** ADD DELETE LIST METHOD *** ---
  Future<void> deleteList(String listId) async {
     await _firestoreService.deleteList(listId);
     // No notifyListeners needed here, the StreamBuilder in created_lists_screen
     // will automatically remove the item when the document is deleted in Firestore.
  }
  // --- *** END ADD DELETE LIST METHOD *** ---

  // --- Remove City/Performer methods if unused ---
  // ...
}
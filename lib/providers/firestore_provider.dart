// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
// Removed unused City/Performer imports

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() { /* ... */ }
  Stream<Show> getShow(String listId) { /* ... */ }
  Future<String> createShow(Show show) async { /* ... */ }
  Future<void> updateShow(String listId, Show show) async { /* ... */ }

  // --- Spot Manipulation Methods (Key-based) ---

  // --- MODIFIED setSpotOver ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    // Pass performerId to the service method
    await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
  }
  // --- END MODIFICATION ---

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... */ }
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }
  Future<void> deleteList(String listId) async { /* ... */ } // Keep delete method

  // --- Remove City/Performer methods if unused ---
}
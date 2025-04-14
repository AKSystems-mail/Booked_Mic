// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String listId) { // Use listId consistently
    return _firestoreService.getShow(listId);
  }

  Future<String> createShow(Show show) async { // Return ID
    String newId = await _firestoreService.createShow(show);
    notifyListeners(); // Notify after creation if lists need refresh elsewhere
    return newId;
  }

  Future<void> updateShow(String listId, Show show) async {
    await _firestoreService.updateShow(listId, show);
    // No notifyListeners needed if UI updates via the Show stream
  }

  // --- Spot Manipulation Methods (Key-based) ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async {
    await _firestoreService.setSpotOver(listId, spotKey, isOver);
    // No notifyListeners needed here
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
    // No notifyListeners needed here
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
    // No notifyListeners needed here
  }

  // --- *** NEW: Method to save reordered spots *** ---
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async {
     await _firestoreService.updateSpotsMap(listId, newSpotsMap);
     // No notifyListeners needed here
  }
  // --- *** END NEW METHOD *** ---

}
// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
// Removed unused City/Performer imports if methods were removed from service
// import 'package:myapp/models/city.dart';
// import 'package:myapp/models/performer.dart';

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String listId) {
    return _firestoreService.getShow(listId);
  }

  Future<String> createShow(Show show) async {
    String newId = await _firestoreService.createShow(show);
    // notifyListeners(); // Only notify if a list widget needs to react directly to creation
    return newId;
  }

  Future<void> updateShow(String listId, Show show) async {
    await _firestoreService.updateShow(listId, show);
    // No notifyListeners needed if UI updates via the Show stream
  }

  // --- Spot Manipulation Methods (Key-based) ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async {
    await _firestoreService.setSpotOver(listId, spotKey, isOver);
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
  }

  // Method to save reordered spots
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async {
     await _firestoreService.updateSpotsMap(listId, newSpotsMap);
     // No notify needed, stream will update UI
  }
  // --- End Spot Manipulation ---

  // --- Remove City/Performer methods if unused ---
  // Stream<List<City>> getCities() { ... }
  // ... etc ...
}
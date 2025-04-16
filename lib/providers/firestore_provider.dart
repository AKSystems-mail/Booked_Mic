// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() { return _firestoreService.getShows(); } // Added return
  Stream<Show> getShow(String listId) { return _firestoreService.getShow(listId); } // Added return
  Future<String> createShow(Show show) async { return await _firestoreService.createShow(show); } // Added return

  // --- MODIFIED updateShow ---
  Future<void> updateShowMap(String listId, Map<String, dynamic> updateData) async {
    // Call service method that accepts a Map
    await _firestoreService.updateShow(listId, updateData);
  }

    // In FirestoreProvider class

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    try {
      await _firestoreService.addManualNameToSpot(listId, spotKey, name);
      // No need to notifyListeners() here if the UI is listening to the Stream from getShow()
      // If other parts of the UI depend directly on this provider's state *after* this operation,
      // you might uncomment the line below.
      // notifyListeners();
    } catch (e) {
      // Optionally handle/rethrow the error for the UI
      rethrow;
    }
  }

  // --- END MODIFICATION ---
 // --- Ensure this method exists ---
  Future<void> deleteList(String listId) async {
     await _firestoreService.deleteList(listId);
     // No notifyListeners needed here for deletion affecting a StreamBuilder
  }
  // --- End Method ---
}
  // --- Spot Manipulation Methods ---
// In FirestoreProvider class

  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    try {
      await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
      // notifyListeners(); // Probably not needed if UI is listening to stream
    } catch (e) {
       print("FirestoreProvider: Error calling setSpotOver service: $e");
       rethrow;
    }
  }
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  // In FirestoreProvider class

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    try {
      await _firestoreService.removePerformerFromSpot(listId, spotKey);
      // No need to notifyListeners() if UI listens to the stream
    } catch (e) {
       rethrow;
    }
  }
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }

  // --- Remove City/Performer methods if unused ---

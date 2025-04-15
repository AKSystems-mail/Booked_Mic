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
  // --- END MODIFICATION ---


  // --- Spot Manipulation Methods ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async { /* ... */ }
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async { /* ... */ }
  Future<void> removePerformerFromSpot(String listId, String spotKey) async { /* ... */ }
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async { /* ... */ }
  Future<void> deleteList(String listId) async { /* ... */ }

  // --- Remove City/Performer methods if unused ---
}
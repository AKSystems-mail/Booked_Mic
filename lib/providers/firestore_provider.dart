// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
// Removed unused City/Performer imports

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() { // Added return type
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String listId) { // Added return type
    return _firestoreService.getShow(listId);
  }

  Future<String> createShow(Show show) async { // Added return type
    String newId = await _firestoreService.createShow(show);
    return newId;
  }

  Future<void> updateShow(String listId, Show show) async {
    await _firestoreService.updateShow(listId, show);
  }

  // --- Spot Manipulation Methods (Key-based) ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async { // Added performerId
    await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
  }

  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async {
     await _firestoreService.updateSpotsMap(listId, newSpotsMap);
  }

  Future<void> deleteList(String listId) async {
     await _firestoreService.deleteList(listId);
  }
  // --- End Spot Manipulation ---

  // --- Remove City/Performer methods if unused ---
}
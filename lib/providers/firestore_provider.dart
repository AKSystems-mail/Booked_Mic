// lib/providers/firestore_provider.dart

import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';


import 'package:myapp/models/show.dart';
// Removed unused City/Performer imports

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() { return _firestoreService.getShows(); }
  Stream<Show> getShow(String listId) { return _firestoreService.getShow(listId); }
  Future<String> createShow(Show show) async { return await _firestoreService.createShow(show); }
  // Assumes updateShowMap exists in service now
  Future<void> updateShowMap(String listId, Map<String, dynamic> updateData) async { await _firestoreService.updateShow(listId, updateData); }

  // --- Spot Manipulation Methods (Key-based) ---

  // --- ADDED setSpotOver ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
    // No notifyListeners needed here, StreamBuilder handles UI update
  }
  // --- END ADDED ---

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
    // No notifyListeners needed here
  }

  // --- ADDED removePerformerFromSpot ---
  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
    // No notifyListeners needed here
  }
  // --- END ADDED ---

  // --- ADDED saveReorderedSpots ---
  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async {
     await _firestoreService.updateSpotsMap(listId, newSpotsMap);
     // No notifyListeners needed here
  }
  // --- END ADDED ---

  // --- ADDED deleteList ---
  Future<void> deleteList(String listId) async {
     await _firestoreService.deleteList(listId);
     // No notifyListeners needed here
  }
  // --- END ADDED ---
  Future<void> resetListSpots(String listId) async {
    await _firestoreService.resetListSpots(listId);
    // No notifyListeners needed here, the Show stream will update the UI
  }

   Stream<int> getBucketSignupCountStream(String listId) {
     return _firestoreService.getBucketSignupCountStream(listId);
  }

  Future<bool> isUserInBucket(String listId, String userId) async {
     return await _firestoreService.isUserInBucket(listId, userId);
  }

  Future<void> addUserToBucket(String listId, String userId, String stageName) async {
     await _firestoreService.addUserToBucket(listId, userId, stageName);
     // No notifyListeners needed, count stream will update UI
  }

  Future<void> removeUserFromBucket(String listId, String userId) async {
     await _firestoreService.removeUserFromBucket(listId, userId);
     // No notifyListeners needed, count stream will update UI
  }
 
   Future<int> getBucketSignupCount(String listId) async {
     return await _firestoreService.getBucketSignupCount(listId);
  }
  // --- Remove City/Performer methods if unused ---
}
// lib/providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/models/city.dart';
import 'package:myapp/models/performer.dart';
// Removed Signup import if subcollection is not used
// import 'package:myapp/models/signup.dart';

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String showId) { // Changed parameter name for clarity
    return _firestoreService.getShow(showId);
  }

  Future<void> createShow(Show show) async {
    await _firestoreService.createShow(show);
    notifyListeners();
  }

  Future<void> updateShow(String showId, Show show) async { // Changed parameter name
    await _firestoreService.updateShow(showId, show);
    notifyListeners();
  }

  // --- Spot Manipulation Methods (Key-based) ---
  Future<void> setSpotOver(String showId, String spotKey, bool isOver) async {
    await _firestoreService.setSpotOver(showId, spotKey, isOver);
    // No notifyListeners needed here if UI updates via the Show stream
  }

  Future<void> addManualNameToSpot(String showId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(showId, spotKey, name);
    // No notifyListeners needed here if UI updates via the Show stream
  }

  Future<void> removePerformerFromSpot(String showId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(showId, spotKey);
    // No notifyListeners needed here if UI updates via the Show stream
  }
  // --- End Spot Manipulation ---


  // --- REMOVED Methods related to 'spotsList' array ---
  // Future<void> addNameToSpot(String showId, int index, String name) async { ... }
  // Future<void> removeNameFromSpot(String showId, int index) async { ... }
  // Future<void> reorderSpots(String showId, int oldIndex, int newIndex) async { ... }
  // --- End REMOVED ---

  // --- REMOVED Methods related to 'bucketNames' array ---
  // Future<void> removeBucketName(String showId, String name) async { ... }
  // Future<List<String>> getBucketNames(String showId) async { ... }
  // --- End REMOVED ---

  // --- REMOVED Methods related to 'signups' subcollection (unless needed) ---
  // Stream<List<Signup>> getSignups(String showId) { ... }
  // Future<void> addPerformerToSignup(String showId, Signup signup) async { ... }
  // Future<void> updatePerformerInSignup(String showId, String performerId, Signup updatedPerformer) async { ... }
  // --- End REMOVED ---


  // --- Keep City/Performer methods if used elsewhere ---
  Stream<List<City>> getCities() { return _firestoreService.getCities(); }
  Future<void> addCity(City city) async { await _firestoreService.addCity(city); notifyListeners(); }
  Future<void> updateCity(String cityId, City city) async { await _firestoreService.updateCity(cityId, city); notifyListeners(); }
  Stream<List<Performer>> getPerformers() { return _firestoreService.getPerformers(); }
  Future<void> addPerformer(Performer performer) async { await _firestoreService.addPerformer(performer); notifyListeners(); }
  Future<void> updatePerformer(Performer updatedPerformer) async { await _firestoreService.updatePerformer(updatedPerformer); notifyListeners(); }
  // --- End City/Performer ---

}
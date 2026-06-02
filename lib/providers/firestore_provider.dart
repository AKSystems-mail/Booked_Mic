// providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/models/performer.dart';
import 'package:myapp/models/city.dart';
//

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String showId) {
    return _firestoreService.getShow(showId);
  }

  // --- Show Methods ---

  Future<void> createShow(Show show) async {
    await _firestoreService.createShow(show);
    notifyListeners();
  }

  Future<void> updateShow(String showId, Map<String, dynamic> updateData) async {
    await _firestoreService.updateShow(showId, updateData);
    notifyListeners();
  }

  Future<void> updatePerformerInSignup(String showId, String performerId, Performer updatedPerformer) async {
    await _firestoreService.updatePerformerInSignup(showId, performerId, updatedPerformer);
    notifyListeners();
  }

  Stream<List<City>> getCities() {
    return _firestoreService.getCities();
  }

  Future<void> addCity(City city) async {
    await _firestoreService.addCity(city);
    notifyListeners();
  }

  Future<void> updateCity(String cityId, City city) async {
    await _firestoreService.updateCity(cityId, city);
    notifyListeners();
  }

  Stream<List<Performer>> getPerformers() {
    return _firestoreService.getPerformers();
  }

  Future<void> addPerformer(Performer performer) async {
    await _firestoreService.addPerformer(performer);
    notifyListeners();
  }

  Future<void> updatePerformer(Performer performer, Performer updatedPerformer) async {
    await _firestoreService.updatePerformer(updatedPerformer);
    notifyListeners();
  }

  Future<void> addNameToSpot(String showId, int index, String name) async {
    await _firestoreService.addNameToSpot(showId, index, name);
    notifyListeners();
  }

  Future<void> removeNameFromSpot(String showId, int index) async {
    await _firestoreService.removeNameFromSpot(showId, index);
    notifyListeners();
  }

  Future<void> reorderSpots(String showId, int oldIndex, int newIndex) async {
    await _firestoreService.reorderSpots(showId, oldIndex, newIndex);
    notifyListeners();
  }

  Future<void> removeBucketName(String showId, String name) async {
    await _firestoreService.removeBucketName(showId, name);
    notifyListeners();
  }

  Future<List<String>> getBucketNames(String showId) async {
    return await _firestoreService.getBucketNames(showId);
  }

  Future<Map<String, dynamic>?> drawAndAssignBucketSpot(String listId, String bucketSpotKey) async {
    final result = await _firestoreService.drawAndAssignBucketSpot(listId, bucketSpotKey);
    notifyListeners();
    return result;
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
    notifyListeners();
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
    notifyListeners();
  }

  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
    notifyListeners();
  }
}
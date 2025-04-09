// providers/firestore_provider.dart
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/models/performer.dart';
import 'package:myapp/models/signup.dart';

class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  Stream<Show> getShow(String showId) {
    return _firestoreService.getShow(showId);
  }

  Stream<List<Signup>> getSignups(String showId) {
    return _firestoreService.getSignups(showId);
  }

  Future<void> createShow(Show show) async {
    await _firestoreService.createShow(show);
    notifyListeners();
  }

  Future<void> updateShow(String showId, Show show) async {
    await _firestoreService.updateShow(showId, show);
    notifyListeners();
  }

  Future<void> addPerformerToSignup(String showId, Signup signup) async {
    await _firestoreService.addPerformerToSignup(showId, signup);
    notifyListeners();
  }

  Future<void> updatePerformerInSignup(String showId, String performerId, Signup updatedPerformer) async {
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
}
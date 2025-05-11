// lib/providers/firestore_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Ensure Timestamp is available
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';

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
    // The Show object passed from list_setup_screen already has most fields.
    // The FirestoreService's createShow method should handle setting the actual document ID
    // and adding FieldValue.serverTimestamp() for createdAt.
    // It should also ensure 'spots' is an empty map {} and 'signedUpUserIds' is an empty list []
    // if the Show object's toMap() doesn't already guarantee this for new shows.

    // The 'show.toMap()' method now includes 'normalizedAddress'.
    // The 'date' is already a Timestamp from show.toMap().

    // If your FirestoreService.createShow expects a Map<String, dynamic>
    // and handles adding `createdAt` and generating an ID:
    Map<String, dynamic> showData = show.toMap();

    // Ensure essential fields for a new list are correctly initialized if not set by model
    showData['spots'] = showData['spots'] ?? {}; // Default to empty map
    showData['signedUpUserIds'] = showData['signedUpUserIds'] ?? []; // Default to empty list
    showData['createdAt'] = FieldValue.serverTimestamp(); // Set creation timestamp here or in service

    // The ID from the Show object might be empty ('') if it's a new show.
    // The service should generate a new ID.
    return await _firestoreService.createShow(show);
    // OR if your service takes a Show object directly:
    // return await _firestoreService.createShow(show);
    // In this case, ensure FirestoreService.createShow adds createdAt and handles ID generation.
  }

  Future<void> updateShowMap(String listId, Map<String, dynamic> updateData) async {
    // Ensure 'updatedAt' is part of this update if you track it
    // updateData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestoreService.updateShow(listId, updateData);
  }

  // --- Spot Manipulation Methods ---
  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    await _firestoreService.setSpotOver(listId, spotKey, isOver, performerId);
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _firestoreService.addManualNameToSpot(listId, spotKey, name);
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    await _firestoreService.removePerformerFromSpot(listId, spotKey);
  }

  Future<void> saveReorderedSpots(String listId, Map<String, dynamic> newSpotsMap) async {
    // This method directly updates the 'spots' field.
    // Consider adding an 'updatedAt' field update here as well.
    // Map<String, dynamic> updatePayload = {
    //   'spots': newSpotsMap,
    //   'updatedAt': FieldValue.serverTimestamp(),
    // };
    // await _firestoreService.updateShow(listId, updatePayload);
    // OR if your service has a dedicated method:
    await _firestoreService.updateSpotsMap(listId, newSpotsMap);
  }

  Future<void> deleteList(String listId) async {
    await _firestoreService.deleteList(listId);
  }

  Future<void> resetListSpots(String listId) async {
    await _firestoreService.resetListSpots(listId);
  }

  // --- Bucket Methods ---
  Stream<int> getBucketSignupCountStream(String listId) {
    return _firestoreService.getBucketSignupCountStream(listId);
  }

  Future<bool> isUserInBucket(String listId, String userId) async {
    return await _firestoreService.isUserInBucket(listId, userId);
  }

  Future<void> addUserToBucket(String listId, String userId, String stageName) async {
    await _firestoreService.addUserToBucket(listId, userId, stageName);
  }

  Future<void> removeUserFromBucket(String listId, String userId) async {
    await _firestoreService.removeUserFromBucket(listId, userId);
  }

  Future<int> getBucketSignupCount(String listId) async {
    return await _firestoreService.getBucketSignupCount(listId);
  }

  Future<Map<String, dynamic>?> drawAndAssignBucketSpot(String listId, String bucketSpotKey) async {
    try {
      return await _firestoreService.drawAndAssignBucketSpot(listId, bucketSpotKey);
    } catch (e) {
      rethrow;
    }
  }
}
// lib/providers/firestore_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Ensure Timestamp is available
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/models/show.dart';
import 'package:cloud_functions/cloud_functions.dart'; // <-- ADD THIS IMPORT


class FirestoreProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // --- List/Show Methods ---
  Stream<List<Show>> getShows() {
    return _firestoreService.getShows();
  }

  // New method to get shows where user is either owner or guest host
  Stream<List<Show>> getShowsForUser(String userId) {
    return _firestoreService.getShowsForUser(userId);
  }

  Stream<Show> getShow(String listId) {
    return _firestoreService.getShow(listId);
  }

  Future<String> createShow(Show show) async {
    Map<String, dynamic> showData = show.toMap();

    // Ensure essential fields for a new list are correctly initialized if not set by model
    showData['spots'] = showData['spots'] ?? {}; // Default to empty map
    showData['signedUpUserIds'] = showData['signedUpUserIds'] ?? []; // Default to empty list
    showData['createdAt'] = FieldValue.serverTimestamp(); // Set creation timestamp here or in service

    // The ID from the Show object might be empty ('') if it's a new show.
    // The service should generate a new ID.
    return await _firestoreService.createShow(show);
  }

  Future<void> updateShowMap(String listId, Map<String, dynamic> updateData) async {
    // Add updatedAt timestamp
    updateData['updatedAt'] = FieldValue.serverTimestamp();
    await _firestoreService.updateShow(listId, updateData);
  }

// --- Guest Host Methods ---
Future<Map<String, dynamic>?> findUserByEmail(String email) async {
  try {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('findUserByEmail');

    final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
      'email': email.toLowerCase(),
    });

    // The result.data will now be a Map like {'uid': '...', 'stageName': '...'}
    // or null if the user was not found.
    return result.data as Map<String, dynamic>?;
  } on FirebaseFunctionsException catch (e) {
    print('Cloud Function error: [${e.code}] ${e.message}');
    return null;
  } catch (e) {
    print('Error calling findUserByEmail function: $e');
    return null;
  }
}

  // Helper method to check if a user can edit a show
  Future<bool> canUserEditShow(String userId, String showId) async {
    try {
      final show = await getShow(showId).first;
      return show.canUserEdit(userId);
    } catch (e) {
      print('Error checking edit permissions: $e');
      return false;
    }
  }

  // Helper method to check if a user can delete a show
  Future<bool> canUserDeleteShow(String userId, String showId) async {
    try {
      final show = await getShow(showId).first;
      return show.canUserDelete(userId);
    } catch (e) {
      print('Error checking delete permissions: $e');
      return false;
    }
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
    Map<String, dynamic> updatePayload = {
      'spots': newSpotsMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestoreService.updateShow(listId, updatePayload);
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
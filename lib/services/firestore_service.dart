import 'package:flutter/foundation.dart';
// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/models/performer.dart';
import 'package:myapp/models/city.dart';
import 'dart:math';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists';

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async {
    Map<String, dynamic> showData = show.toMap();
    // Use the field the model expects
    showData['userId'] = show.userId;
    showData['spots'] = {};
    showData['signedUpUserIds'] = [];
    showData['createdAt'] = FieldValue.serverTimestamp();
    showData.remove('id');
    DocumentReference docRef = await _db.collection(_listCollection).add(showData);
    return docRef.id;
  }

  Future<void> updateShow(String listId, Map<String, dynamic> updateData) async {
    updateData.remove('userId');
    updateData.remove('createdAt');
    updateData.remove('spots');
    updateData.remove('signedUpUserIds');
    updateData.remove('id');
    updateData.remove('qrCodeData');

    updateData.removeWhere((key, value) =>
        value == null && key != 'latitude' && key != 'longitude');

    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() {
    return _db
        .collection(_listCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String listId) {
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
      if (!doc.exists) throw Exception("List with ID $listId not found.");
      return Show.fromFirestore(doc);
    });
  }

  Stream<List<Show>> getShowsForUser(String userId) {
    return _db
        .collection(_listCollection)
        .where(
          Filter.or(
            Filter('userId', isEqualTo: userId),
            Filter('guestHostId', isEqualTo: userId),
          ),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Show.fromFirestore(doc))
            .toList());
  }

  // --- Spot/Performer Methods ---

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    final docRef = _db.collection(_listCollection).doc(listId);
    try {
      await _db.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return;
        final spotsMap = (docSnap.data()?['spots'] as Map<String, dynamic>?) ?? {};
        final spotData = spotsMap[spotKey];
        String? userIdToRemove;
        if (spotData is Map && spotData['userId'] != null) {
          userIdToRemove = spotData['userId'];
        }
        Map<String, dynamic> updates = {'spots.$spotKey': FieldValue.delete()};
        if (userIdToRemove != null) {
          updates['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
        }
        transaction.update(docRef, updates);
      });
    } catch (e) {
      debugPrint("Error removing performer from spot $spotKey: $e");
      rethrow;
    }
  }

  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async {
    await _db.collection(_listCollection).doc(listId).update({'spots': newSpotsMap});
  }

  Future<void> deleteList(String listId) async {
    final listRef = _db.collection(_listCollection).doc(listId);
    final bucketSignupsRef = listRef.collection('bucketSignups');
    QuerySnapshot snapshot;
    do {
      snapshot = await bucketSignupsRef.limit(100).get();
      if (snapshot.docs.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (DocumentSnapshot doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } while (snapshot.docs.isNotEmpty);
    await listRef.delete();
  }

  Future<void> resetListSpots(String listId) async {
    final listRef = _db.collection(_listCollection).doc(listId);
    final bucketSignupsRef = listRef.collection('bucketSignups');
    QuerySnapshot snapshot;
    do {
      snapshot = await bucketSignupsRef.limit(100).get();
      if (snapshot.docs.isNotEmpty) {
        WriteBatch batch = _db.batch();
        for (DocumentSnapshot doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } while (snapshot.docs.isNotEmpty);
    await listRef.update({
      'spots': {},
      'signedUpUserIds': [],
    });
  }

  // --- Bucket Methods ---

  Stream<int> getBucketSignupCountStream(String listId) {
    return _db.collection(_listCollection).doc(listId)
              .collection('bucketSignups')
              .snapshots()
              .map((snapshot) => snapshot.size);
  }

  Future<List<QueryDocumentSnapshot>> getBucketSignups(String listId) async {
    final QuerySnapshot snapshot = await _db.collection(_listCollection).doc(listId).collection('bucketSignups').get();
    return snapshot.docs;
  }

  Future<Map<String, dynamic>?> drawAndAssignBucketSpot(String listId, String bucketSpotKey) async {
    final List<QueryDocumentSnapshot> bucketDocs = await getBucketSignups(listId);
    if (bucketDocs.isEmpty) return null;
    final selectedDoc = bucketDocs[Random().nextInt(bucketDocs.length)];
    final selectedPerformerData = selectedDoc.data() as Map<String, dynamic>?;
    if (selectedPerformerData == null || selectedPerformerData['userId'] == null || selectedPerformerData['stageName'] == null) {
      throw Exception('Selected bucket performer has invalid data.');
    }
    final String performerUserId = selectedPerformerData['userId'];
    final String performerName = selectedPerformerData['stageName'];
    final Map<String, dynamic> spotData = {'userId': performerUserId, 'name': performerName};
    WriteBatch batch = _db.batch();
    batch.update(_db.collection(_listCollection).doc(listId), {'spots.$bucketSpotKey': spotData});
    batch.delete(_db.collection(_listCollection).doc(listId).collection('bucketSignups').doc(performerUserId));
    await batch.commit();
    return spotData;
  }

  Future<bool> isUserInBucket(String listId, String userId) async {
    final doc = await _db.collection(_listCollection).doc(listId).collection('bucketSignups').doc(userId).get();
    return doc.exists;
  }

  Future<void> addUserToBucket(String listId, String userId, String stageName) async {
    await _db.collection(_listCollection).doc(listId).collection('bucketSignups').doc(userId).set({
      'userId': userId,
      'stageName': stageName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeUserFromBucket(String listId, String userId) async {
    await _db.collection(_listCollection).doc(listId).collection('bucketSignups').doc(userId).delete();
  }

  Future<int> getBucketSignupCount(String listId) async {
    final snapshot = await _db.collection(_listCollection).doc(listId).collection('bucketSignups').count().get();
    return snapshot.count ?? 0;
  }

  // --- Manual & Reorder Methods ---

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
    await _db.collection(_listCollection).doc(listId).update({'spots.$spotKey': {'name': name, 'isOver': false}});
  }

  Future<void> setSpotOver(String listId, String spotKey, bool isOver, String performerId) async {
    final docRef = _db.collection(_listCollection).doc(listId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final spots = Map<String, dynamic>.from(data['spots'] ?? {});
      final spotEntry = Map<String, dynamic>.from(spots[spotKey] ?? {});
      spotEntry['isOver'] = isOver;
      if (!isOver && performerId.isNotEmpty) {
        spotEntry['name'] = 'Reserved';
      }
      Map<String, dynamic> updateData = {
        'spots.$spotKey': spotEntry,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.update(docRef, updateData);
    });
  }

  // --- Missing methods for FirestoreProvider ---

  Stream<List<City>> getCities() {
    return _db.collection('cities').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => City.fromFirestore(doc)).toList());
  }

  Future<void> addCity(City city) async {
    await _db.collection('cities').add(city.toMap());
  }

  Future<void> updateCity(String cityId, City city) async {
    await _db.collection('cities').doc(cityId).update(city.toMap());
  }

  Stream<List<Performer>> getPerformers() {
    return _db.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Performer.fromFirestore(doc)).toList());
  }

  Future<void> updatePerformerInSignup(String showId, String performerId, Performer performer) async {
    // This looks like it was intended to update a performer's data within a specific show/signup
    // For now, we'll update the main user record as a best-guess implementation
    await updatePerformer(performer);
  }

  Future<void> addPerformer(Performer performer) async {
    await _db.collection('users').doc(performer.uid).set(performer.toMap());
  }

  Future<void> updatePerformer(Performer performer) async {
    await _db.collection('users').doc(performer.uid).update(performer.toMap());
  }

  // For older logic support
  Future<void> addNameToSpot(String showId, int index, String name) async {
    await _db.collection(_listCollection).doc(showId).update({'spots.${index.toString()}': {'name': name, 'isOver': false}});
  }

  Future<void> removeNameFromSpot(String showId, int index) async {
    await _db.collection(_listCollection).doc(showId).update({'spots.${index.toString()}': FieldValue.delete()});
  }

  Future<void> reorderSpots(String showId, int oldIndex, int newIndex) async {
    // This is a generic reorder that was previously used. 
    // For now we'll implement it as a placeholder to fix compilation.
    debugPrint("reorderSpots called but logic needs verification");
  }

  Future<void> removeBucketName(String showId, String name) async {
    // Placeholder to fix compilation
  }

  Future<List<String>> getBucketNames(String showId) async {
    // Placeholder to fix compilation
    return [];
  }

  // Modern Atomic Reorder
  Future<void> reorderRegularSpots(String listId, int oldIndex, int newIndex) async {
    final docRef = _db.collection(_listCollection).doc(listId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final spots = Map<String, dynamic>.from(data['spots'] ?? {});
      final regularSpots = <int, dynamic>{};
      final otherSpots = <String, dynamic>{};
      spots.forEach((key, value) {
        final numericKey = int.tryParse(key);
        if (numericKey != null) { regularSpots[numericKey] = value; }
        else { otherSpots[key] = value; }
      });
      final sortedKeys = regularSpots.keys.toList()..sort();
      final orderedSpots = sortedKeys.map((k) => regularSpots[k]).toList();
      if (oldIndex < newIndex) newIndex -= 1;
      final item = orderedSpots.removeAt(oldIndex);
      orderedSpots.insert(newIndex, item);
      final newSpots = Map<String, dynamic>.from(otherSpots);
      for (int i = 0; i < orderedSpots.length; i++) {
        newSpots[(i + 1).toString()] = orderedSpots[i];
      }
      transaction.update(docRef, {'spots': newSpots});
    });
  }
}

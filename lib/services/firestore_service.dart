// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
// Removed unused model imports if City/Performer methods are removed
// import 'package:myapp/models/performer.dart';
// import 'package:myapp/models/city.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists'; // Consistent collection name
  // final String _userCollection = 'users'; // Keep if user methods needed

  // --- List/Show Methods ---

  Future<String> createShow(Show show) async {
    Map<String, dynamic> showData = show.toMap();
    // Ensure required fields for creation are present
    showData['userId'] = show.userId;
    showData['spots'] = {}; // Ensure starts empty
    showData['signedUpUserIds'] = []; // Ensure starts empty
    showData['createdAt'] = FieldValue.serverTimestamp();
    showData.remove('id'); // Let Firestore generate ID

    DocumentReference docRef = await _db.collection(_listCollection).add(showData);
    return docRef.id;
  }

  Future<void> updateShow(String listId, Show show) async {
    // Only update fields editable by the host
    Map<String, dynamic> updateData = {
      'listName': show.showName,
      'address': show.address,
      'state': show.state,
      'date': Timestamp.fromDate(show.date),
      'latitude': show.latitude,
      'longitude': show.longitude,
      'numberOfSpots': show.numberOfSpots,
      'numberOfWaitlistSpots': show.numberOfWaitlistSpots, // Match model/Firestore
      'numberOfBucketSpots': show.numberOfBucketSpots, // Match model/Firestore
      'bucketSpots': show.bucketSpots, // Keep flag if used
      // Add cutoffDate if editable
      if (show.cutoffDate != null) 'cutoffDate': Timestamp.fromDate(show.cutoffDate!),
    };
    updateData.removeWhere((key, value) => value == null && key != 'latitude' && key != 'longitude'); // Allow setting coords to null

    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() {
    // Query 'Lists' collection
    return _db.collection(_listCollection).orderBy('createdAt', descending: true) // Example sort
           .snapshots().map((snapshot) =>
              snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String listId) {
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
       if (!doc.exists) throw Exception("List with ID $listId not found.");
       return Show.fromFirestore(doc);
    });
  }

  // --- Spot Map Manipulation Methods ---

  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async {
     try {
        await _db.collection(_listCollection).doc(listId).update({'spots.$spotKey.isOver': isOver});
     } catch (e) { print("Error setting spot $spotKey over: $e"); rethrow; }
  }

  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
     try {
        final spotData = {'name': name, 'isOver': false}; // No userId
        await _db.collection(_listCollection).doc(listId).update({'spots.$spotKey': spotData});
     } catch (e) { print("Error adding manual name to spot $spotKey: $e"); rethrow; }
  }

  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    // This logic now correctly handles removing potential userId from signedUpUserIds
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

          // Prepare updates within transaction
          Map<String, dynamic> updates = {'spots.$spotKey': FieldValue.delete()};
          if (userIdToRemove != null) {
             updates['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
          }
          transaction.update(docRef, updates);
       });
       print("Successfully removed spot $spotKey");
       // Cloud function handles shifting
    } catch (e) { print("Error removing performer from spot $spotKey: $e"); rethrow; }
  }

  // Method to save the entire reordered spots map
  Future<void> updateSpotsMap(String listId, Map<String, dynamic> newSpotsMap) async {
     try {
        await _db.collection(_listCollection).doc(listId).update({'spots': newSpotsMap});
        print("Successfully updated spots map for list $listId");
     } catch (e) { print("Error updating spots map for list $listId: $e"); rethrow; }
  }
  // --- End Spot Map Manipulation ---

  // --- Remove City/Performer methods if unused ---
  // Stream<List<City>> getCities() { /* ... */ }
  // ... etc ...
}

// --- Dummy Models (Remove if you have real ones) ---
class City { String id; String name; City({required this.id, required this.name}); Map<String, dynamic> toMap() => {'name': name}; static City fromFirestore(DocumentSnapshot doc) { var d = doc.data() as Map<String, dynamic>? ?? {}; return City(id: doc.id, name: d['name'] ?? ''); } }
class Performer { String id; String name; Performer({required this.id, required this.name}); Map<String, dynamic> toMap() => {'name': name}; static Performer fromFirestore(DocumentSnapshot doc) { var d = doc.data() as Map<String, dynamic>? ?? {}; return Performer(id: doc.id, name: d['name'] ?? ''); } }
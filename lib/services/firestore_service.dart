// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
// Assuming Spot model is NOT used anymore with the map structure
// import 'package:myapp/models/spot.dart';
import 'package:myapp/models/performer.dart'; // Keep if performer logic is used
import 'package:myapp/models/signup.dart'; // Keep if signup subcollection is used
import 'package:myapp/models/city.dart'; // Keep if city logic is used

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _listCollection = 'Lists'; // Use consistent collection name
  final String _userCollection = 'users'; // Assuming user collection name

  // --- List/Show Methods (Using 'Lists' collection and 'spots' map) ---

  Future<void> createShow(Show show) async {
    // Convert Show object to Map, ensuring 'spots' is an empty map
    // and 'signedUpUserIds' is an empty list initially.
    // The Show model's toMap() should handle this.
    // Ensure 'userId' is set correctly before calling this.
    Map<String, dynamic> showData = show.toMap();
    showData['spots'] = {}; // Explicitly ensure spots map is empty
    showData['signedUpUserIds'] = []; // Explicitly ensure array is empty
    showData['createdAt'] = FieldValue.serverTimestamp(); // Add server timestamp

    // Use the correct collection name
    await _db.collection(_listCollection).add(showData);
  }

  Future<void> updateShow(String listId, Show show) async {
    // Only update fields editable by the host (as defined in rules)
    // Exclude fields like userId, createdAt, spots, signedUpUserIds
    Map<String, dynamic> updateData = {
      'listName': show.listName,
      'address': show.address,
      'state': show.state,
      'date': show.date, // Assuming date is a Timestamp or DateTime converted in toMap
      'latitude': show.latitude,
      'longitude': show.longitude,
      'numberOfSpots': show.numberOfSpots,
      'numberOfWaitlistSpots': show.waitListSpots, // Field name mismatch? Check Show model
      'numberOfBucketSpots': show.numberOfBucketSpots, // Field name mismatch? Check Show model
    };
    // Use the correct collection name
    await _db.collection(_listCollection).doc(listId).update(updateData);
  }

  Stream<List<Show>> getShows() {
    // Use the correct collection name
    return _db.collection(_listCollection).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String listId) {
    // Use the correct collection name
    return _db.collection(_listCollection).doc(listId).snapshots().map((doc) {
       if (!doc.exists) {
          throw Exception("List with ID $listId not found.");
       }
       return Show.fromFirestore(doc);
    });
  }

  // Method to set the 'isOver' flag for a specific spot
  Future<void> setSpotOver(String listId, String spotKey, bool isOver) async {
     try {
        // Use the correct collection name
        await _db.collection(_listCollection).doc(listId).update({
           'spots.$spotKey.isOver': isOver
        });
        print("Successfully set spot $spotKey to over: $isOver");
     } catch (e) {
        print("Error setting spot $spotKey over: $e");
        // Rethrow the error so the provider/UI can handle it if needed
        rethrow;
     }
  }

  // Method for HOST to manually add a name to an available spot
  Future<void> addManualNameToSpot(String listId, String spotKey, String name) async {
     try {
        // Creates the map structure, no userId as host added manually
        final spotData = {'name': name, 'isOver': false};
        // Use the correct collection name
        await _db.collection(_listCollection).doc(listId).update({
           'spots.$spotKey': spotData
        });
        print("Successfully added manual name '$name' to spot $spotKey");
     } catch (e) {
        print("Error adding manual name to spot $spotKey: $e");
        rethrow;
     }
  }

  // Method for HOST to remove any performer/name from a spot
  Future<void> removePerformerFromSpot(String listId, String spotKey) async {
    try {
      // Get the current spot data to see if we need to remove from signedUpUserIds
      final docSnap = await _db.collection(_listCollection).doc(listId).get();
      final spotsMap = (docSnap.data()?['spots'] as Map<String, dynamic>?) ?? {};
      final spotData = spotsMap[spotKey];
      String? userIdToRemove;
      if (spotData is Map && spotData['userId'] != null) {
         userIdToRemove = spotData['userId'];
      }

      // Prepare updates
      Map<String, dynamic> updates = {
         'spots.$spotKey': FieldValue.delete() // Delete the spot entry
      };
      if (userIdToRemove != null) {
         // If a user was associated, remove them from the array too
         updates['signedUpUserIds'] = FieldValue.arrayRemove([userIdToRemove]);
      }

      // Use the correct collection name
      await _db.collection(_listCollection).doc(listId).update(updates);
      print("Successfully removed spot $spotKey");
      // Note: Cloud function should handle shifting if needed
    } catch (e) {
      print("Error removing performer from spot $spotKey: $e");
      rethrow;
    }
  }


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
  // Future<void> updatePerformerInSignup(String showId, String performerId, Signup signup) async { ... }
  // --- End REMOVED ---

  // --- Keep City/Performer methods if they are used elsewhere ---
  Stream<List<City>> getCities() { /* ... */ return _db.collection('cities').snapshots().map((s) => s.docs.map((d) => City.fromFirestore(d)).toList()); }
  Future<void> addCity(City city) async { /* ... */ await _db.collection('cities').add(city.toMap()); }
  Future<void> updateCity(String cityId, City city) async { /* ... */ await _db.collection('cities').doc(cityId).update(city.toMap()); }
  Stream<List<Performer>> getPerformers() { /* ... */ return _db.collection('performers').snapshots().map((s) => s.docs.map((d) => Performer.fromFirestore(d)).toList()); }
  Future<void> addPerformer(Performer performer) async { /* ... */ await _db.collection('performers').add(performer.toMap()); }
  Future<void> updatePerformer(Performer performer) async { /* ... */ await _db.collection('performers').doc(performer.id).update(performer.toMap()); }
  // --- End City/Performer ---

}

// --- Dummy Models (Replace with your actual models) ---
class City { String id; String name; City({required this.id, required this.name}); Map<String, dynamic> toMap() => {'name': name}; static City fromFirestore(DocumentSnapshot doc) { var d = doc.data() as Map<String, dynamic>? ?? {}; return City(id: doc.id, name: d['name'] ?? ''); } }
// class Signup { String id; String name; Signup({required this.id, required this.name}); Map<String, dynamic> toMap() => {'name': name}; static Signup fromFirestore(DocumentSnapshot doc) { var d = doc.data() as Map<String, dynamic>? ?? {}; return Signup(id: doc.id, name: d['name'] ?? ''); } }
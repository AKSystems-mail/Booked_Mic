// services/firestore_service
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/show.dart';
import 'package:myapp/models/performer.dart';
import 'package:myapp/models/signup.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createShow(Show show) async {
    await _db.collection('shows').add(show.toMap());
  }

  Future<void> updateShow(String showId, Show show) async {
    await _db.collection('shows').doc(showId).update(show.toMap());
  }

  Stream<List<Show>> getShows() {
    return _db.collection('shows').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Show.fromFirestore(doc)).toList());
  }

  Stream<Show> getShow(String showId) {
    return _db.collection('shows').doc(showId).snapshots().map((doc) => Show.fromFirestore(doc));
  }

  Stream<List<Signup>> getSignups(String showId) {
    return _db.collection('shows').doc(showId).collection('signups').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Signup.fromFirestore(doc)).toList());
  }

  Future<void> addPerformerToSignup(String showId, Signup signup) async {
    await _db.collection('shows').doc(showId).collection('signups').add(signup.toMap());
  }

  Future<void> updatePerformerInSignup(String showId, String performerId, Signup signup) async {
    await _db.collection('shows').doc(showId).collection('signups').doc(performerId).update(signup.toMap());
  }

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
    return _db.collection('performers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Performer.fromFirestore(doc)).toList());
  }

  Future<void> addPerformer(Performer performer) async {
    await _db.collection('performers').add(performer.toMap());
  }

  Future<void> updatePerformer(Performer performer) async {
    await _db.collection('performers').doc(performer.id).update(performer.toMap());
  }

  Future<void> addNameToSpot(String showId, int index, String name) async {
    await _db.collection('shows').doc(showId).update({
      'spotsList.$index.name': name,
    });
  }

  Future<void> removeNameFromSpot(String showId, int index) async {
    await _db.collection('shows').doc(showId).update({
      'spotsList.$index.name': FieldValue.delete(),
    });
  }

  Future<void> reorderSpots(String showId, int oldIndex, int newIndex) async {
    final showDoc = await _db.collection('shows').doc(showId).get();
    final show = Show.fromFirestore(showDoc);
    final spotsList = show.spotsList;
    final spot = spotsList.removeAt(oldIndex);
    spotsList.insert(newIndex, spot);
    await _db.collection('shows').doc(showId).update({
      'spotsList': spotsList.map((spot) => spot.toMap()).toList(),
    });
  }

  Future<void> removeBucketName(String showId, String name) async {
    await _db.collection('shows').doc(showId).update({
      'bucketNames': FieldValue.arrayRemove([name]),
    });
  }

  Future<List<String>> getBucketNames(String showId) async {
    final showDoc = await _db.collection('shows').doc(showId).get();
    final show = Show.fromFirestore(showDoc);
    return show.bucketNames;
  }
}
// lib/models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Show {
  final String id;
  final String showName;
  final DateTime date;
  final String address;
  final String normalizedAddress; // <<< ADDED
  final String state;
  final double? latitude;
  final double? longitude;
  final int numberOfSpots;
  final bool bucketSpots;
  final int numberOfWaitlistSpots;
  final int numberOfBucketSpots;
  final DateTime? cutoffDate;
  final String userId;
  final Timestamp? createdAt; // Keep as Timestamp for Firestore interaction
  final Map<String, dynamic> spots;
  final List<String> signedUpUserIds;
  final bool isSearchable;

  Show({
    required this.id,
    required this.showName,
    required this.date,
    required this.address,
    required this.normalizedAddress, // <<< ADDED
    required this.state,
    this.latitude,
    this.longitude,
    required this.numberOfSpots,
    required this.bucketSpots,
    required this.numberOfWaitlistSpots,
    required this.numberOfBucketSpots,
    this.cutoffDate,
    required this.userId,
    this.createdAt,
    required this.spots,
    required this.signedUpUserIds,
    this.isSearchable = true,
  });

  factory Show.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      // Fallback if date is stored as ISO string (less ideal)
      parsedDate = DateTime.tryParse(data['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now(); // Default if missing or wrong type
    }

    DateTime? parsedCutoffDate;
    if (data['cutoffDate'] is Timestamp) {
      parsedCutoffDate = (data['cutoffDate'] as Timestamp).toDate();
    } else if (data['cutoffDate'] is String) {
      parsedCutoffDate = DateTime.tryParse(data['cutoffDate']);
    }


    return Show(
      id: doc.id,
      showName: data['listName'] ?? '', // Matches Firestore field 'listName'
      date: parsedDate,
      address: data['address'] ?? '',
      normalizedAddress: data['normalizedAddress'] ?? (data['address'] ?? '').trim().toLowerCase(), // <<< ADDED (with fallback)
      state: data['state'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      numberOfSpots: data['numberOfSpots'] ?? 0,
      bucketSpots: data['bucketSpots'] ?? false,
      numberOfWaitlistSpots: data['numberOfWaitlistSpots'] ?? 0,
      numberOfBucketSpots: data['numberOfBucketSpots'] ?? 0,
      cutoffDate: parsedCutoffDate,
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      spots: Map<String, dynamic>.from(data['spots'] ?? {}),
      signedUpUserIds: List<String>.from(data['signedUpUserIds'] ?? []),
      isSearchable: data['isSearchable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    // This map is used when creating/updating a document in Firestore
    Map<String, dynamic> map = {
      // 'listId': id, // Usually not needed to store id inside the doc if doc.id is used
      'listName': showName,
      'date': Timestamp.fromDate(date), // Convert DateTime to Timestamp for Firestore
      'address': address,
      'normalizedAddress': normalizedAddress.trim().toLowerCase(), // <<< ADDED & Ensure normalization
      'state': state,
      'numberOfSpots': numberOfSpots,
      'bucketSpots': bucketSpots,
      'numberOfWaitlistSpots': numberOfWaitlistSpots,
      'numberOfBucketSpots': numberOfBucketSpots,
      'userId': userId,
      'spots': spots, // Should be an empty map {} on creation
      'signedUpUserIds': signedUpUserIds,
      'isSearchable': isSearchable,
       // Should be an empty list [] on creation
      // createdAt is typically set by FieldValue.serverTimestamp() in the service/provider
    };

    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (cutoffDate != null) map['cutoffDate'] = Timestamp.fromDate(cutoffDate!);
    // 'createdAt' will be handled by the FirestoreProvider on creation.

    return map;
  }
}
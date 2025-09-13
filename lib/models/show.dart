// lib/models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Show {
  final String id;
  final String showName;
  final DateTime date;
  final String address;
  final String normalizedAddress;
  final String state;
  final double? latitude;
  final double? longitude;
  final int numberOfSpots;
  final bool bucketSpots;
  final int numberOfWaitlistSpots;
  final int numberOfBucketSpots;
  final DateTime? cutoffDate;
  final String userId;
  final Timestamp? createdAt;
  final Map<String, dynamic> spots;
  final List<String> signedUpUserIds;
  final bool isSearchable;
  final String? guestHostStageName; // <-- ADD THIS NEW FIELD

  
  // New fields for guest host functionality
  final String? guestHostId;
  final String? guestHostEmail;
  final bool isGuestHostActive;

  Show({
    required this.id,
    required this.showName,
    required this.date,
    required this.address,
    required this.normalizedAddress,
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
    // Initialize new fields
    this.guestHostId,
    this.guestHostEmail,
    this.isGuestHostActive = false,
    this.guestHostStageName, // <-- ADD TO CONSTRUCTOR

  });

  factory Show.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      parsedDate = DateTime.tryParse(data['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedCutoffDate;
    if (data['cutoffDate'] is Timestamp) {
      parsedCutoffDate = (data['cutoffDate'] as Timestamp).toDate();
    } else if (data['cutoffDate'] is String) {
      parsedCutoffDate = DateTime.tryParse(data['cutoffDate']);
    }

    return Show(
      id: doc.id,
      showName: data['listName'] ?? '',
      date: parsedDate,
      address: data['address'] ?? '',
      normalizedAddress: data['normalizedAddress'] ??
          (data['address'] ?? '').trim().toLowerCase(),
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
      // New fields with fallback values
      guestHostId: data['guestHostId'],
      guestHostEmail: data['guestHostEmail'],
      isGuestHostActive: data['isGuestHostActive'] ?? false,
      guestHostStageName: data['guestHostStageName'],
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'listName': showName,
      'date': Timestamp.fromDate(date),
      'address': address,
      'normalizedAddress': normalizedAddress.trim().toLowerCase(),
      'state': state,
      'numberOfSpots': numberOfSpots,
      'bucketSpots': bucketSpots,
      'numberOfWaitlistSpots': numberOfWaitlistSpots,
      'numberOfBucketSpots': numberOfBucketSpots,
      'userId': userId,
      'spots': spots,
      'signedUpUserIds': signedUpUserIds,
      'isSearchable': isSearchable,
      // Include new fields in Firestore document
      'isGuestHostActive': isGuestHostActive,
      'guestHostStageName': guestHostStageName,
    };

    // Only include guest host fields if they have values
    if (guestHostId != null) map['guestHostId'] = guestHostId;
    if (guestHostEmail != null) map['guestHostEmail'] = guestHostEmail;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (cutoffDate != null) map['cutoffDate'] = Timestamp.fromDate(cutoffDate!);

    return map;
  }

  // Helper method to check if a user can edit this show
  bool canUserEdit(String userId) {
    return userId == this.userId || userId == guestHostId;
  }

  // Helper method to check if a user can delete this show
  bool canUserDelete(String userId) {
    return userId == this.userId;
  }

  // Create a copyWith method for easier updates
  Show copyWith({
    String? id,
    String? showName,
    DateTime? date,
    String? address,
    String? normalizedAddress,
    String? state,
    double? latitude,
    double? longitude,
    int? numberOfSpots,
    bool? bucketSpots,
    int? numberOfWaitlistSpots,
    int? numberOfBucketSpots,
    DateTime? cutoffDate,
    String? userId,
    Timestamp? createdAt,
    Map<String, dynamic>? spots,
    List<String>? signedUpUserIds,
    bool? isSearchable,
    String? guestHostId,
    String? guestHostEmail,
    bool? isGuestHostActive,
  }) {
    return Show(
      id: id ?? this.id,
      showName: showName ?? this.showName,
      date: date ?? this.date,
      address: address ?? this.address,
      normalizedAddress: normalizedAddress ?? this.normalizedAddress,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      numberOfSpots: numberOfSpots ?? this.numberOfSpots,
      bucketSpots: bucketSpots ?? this.bucketSpots,
      numberOfWaitlistSpots: numberOfWaitlistSpots ?? this.numberOfWaitlistSpots,
      numberOfBucketSpots: numberOfBucketSpots ?? this.numberOfBucketSpots,
      cutoffDate: cutoffDate ?? this.cutoffDate,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      spots: spots ?? this.spots,
      signedUpUserIds: signedUpUserIds ?? this.signedUpUserIds,
      isSearchable: isSearchable ?? this.isSearchable,
      guestHostId: guestHostId ?? this.guestHostId,
      guestHostEmail: guestHostEmail ?? this.guestHostEmail,
      isGuestHostActive: isGuestHostActive ?? this.isGuestHostActive,
    );
  }
}
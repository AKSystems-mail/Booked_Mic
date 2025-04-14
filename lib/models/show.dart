// lib/models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// Removed unused 'package:flutter/material.dart';

class Show {
  final String id;
  final String showName;
  final DateTime date;
  final String address;
  final String state;
  final double? latitude;
  final double? longitude;
  final int numberOfSpots;
  // Removed reservedSpots, waitList, bucketNames - assuming handled by spots map logic now
  // final List<String> reservedSpots;
  // final List<String> waitList;
  // final List<String> bucketNames;
  final bool bucketSpots; // Keep flag if needed for UI logic?
  final int numberOfWaitlistSpots; // Correct field name
  final int numberOfBucketSpots; // Correct field name
  final DateTime? cutoffDate;
  // Removed cutoffTime - wasn't being used
  // final TimeOfDay? cutoffTime;
  final String userId;
  final Timestamp? createdAt;
  final Map<String, dynamic> spots; // Use Map
  final List<String> signedUpUserIds; // Use List<String>

  Show({
    required this.id,
    required this.showName,
    required this.date,
    required this.address,
    required this.state,
    this.latitude,
    this.longitude,
    required this.numberOfSpots,
    // required this.reservedSpots,
    required this.bucketSpots,
    required this.numberOfWaitlistSpots,
    required this.numberOfBucketSpots,
    // required this.waitList,
    // required this.bucketNames,
    this.cutoffDate,
    // this.cutoffTime,
    required this.userId,
    this.createdAt,
    required this.spots,
    required this.signedUpUserIds,
  });

  factory Show.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    if (data['date'] is Timestamp) {
       parsedDate = (data['date'] as Timestamp).toDate();
    } else {
       parsedDate = DateTime.now();
       print("Warning: Missing or invalid 'date' field for show ${doc.id}");
    }

    return Show(
      id: doc.id,
      showName: data['listName'] ?? '', // Match Firestore field
      date: parsedDate,
      address: data['address'] ?? '',
      state: data['state'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      numberOfSpots: data['numberOfSpots'] ?? 0,
      // reservedSpots: List<String>.from(data['reservedSpots'] ?? []),
      bucketSpots: data['bucketSpots'] ?? false, // Assuming this flag might still be used
      numberOfWaitlistSpots: data['numberOfWaitlistSpots'] ?? 0, // Match Firestore field
      numberOfBucketSpots: data['numberOfBucketSpots'] ?? 0, // Match Firestore field
      // waitList: List<String>.from(data['waitList'] ?? []),
      // bucketNames: List<String>.from(data['bucketNames'] ?? []),
      cutoffDate: (data['cutoffDate'] as Timestamp?)?.toDate(),
      // cutoffTime: parsedTime, // Removed
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      spots: Map<String, dynamic>.from(data['spots'] ?? {}), // Get spots map
      signedUpUserIds: List<String>.from(data['signedUpUserIds'] ?? []), // Get array
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listName': showName,
      'date': Timestamp.fromDate(date),
      'address': address,
      'state': state,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'numberOfSpots': numberOfSpots,
      // 'reservedSpots': reservedSpots,
      'bucketSpots': bucketSpots,
      'numberOfWaitlistSpots': numberOfWaitlistSpots,
      'numberOfBucketSpots': numberOfBucketSpots,
      // 'waitList': waitList,
      // 'bucketNames': bucketNames,
      if (cutoffDate != null) 'cutoffDate': Timestamp.fromDate(cutoffDate!),
      // 'cutoffTime': timeString, // Removed
      'userId': userId,
      // createdAt is set by server or on create
      'spots': spots,
      'signedUpUserIds': signedUpUserIds,
    };
  }
}
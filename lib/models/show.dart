// lib/models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Keep for TimeOfDay if used

class Show {
  final String id;
  final String showName;
  final DateTime date; // Use DateTime
  final String address; // Use address
  final String state; // Keep state
  final double? latitude; // Optional coordinates
  final double? longitude; // Optional coordinates
  final int numberOfSpots; // Renamed from 'spots' for clarity
  final List<String> reservedSpots; // Keep if needed, or remove if handled in 'spots' map
  final bool bucketSpots; // Keep flag if needed
  final int numberOfWaitlistSpots; // Renamed for clarity
  final int numberOfBucketSpots; // Added for clarity
  final List<String> waitList; // Keep if needed, or remove if handled in 'spots' map
  final List<String> bucketNames; // Keep if needed, or remove if handled in 'spots' map
  final DateTime? cutoffDate; // Optional
  final TimeOfDay? cutoffTime; // Optional
  final String userId; // ID of the host who created it
  final Timestamp? createdAt; // Added for sorting
  final Map<String, dynamic> spots; // *** Use Map for spots ***
  final List<String> signedUpUserIds; // Keep for queries

  Show({
    required this.id,
    required this.showName,
    required this.date,
    required this.address,
    required this.state,
    this.latitude,
    this.longitude,
    required this.numberOfSpots,
    required this.reservedSpots,
    required this.bucketSpots,
    required this.numberOfWaitlistSpots, // Use new name
    required this.numberOfBucketSpots, // Use new name
    required this.waitList,
    required this.bucketNames,
    this.cutoffDate,
    this.cutoffTime,
    required this.userId,
    this.createdAt,
    required this.spots, // Add spots map
    required this.signedUpUserIds, // Add signedUpUserIds
  });

  // Convert Firestore Timestamp and TimeOfDay string/map back
  factory Show.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    // Handle potential null or incorrect date format
    DateTime parsedDate;
    if (data['date'] is Timestamp) {
       parsedDate = (data['date'] as Timestamp).toDate();
    } else {
       // Provide a default or handle error if date is crucial and missing/wrong type
       parsedDate = DateTime.now(); // Example default
       print("Warning: Missing or invalid 'date' field for show ${doc.id}");
    }

    // Handle TimeOfDay (assuming stored as string HH:mm or map) - Optional
    TimeOfDay? parsedTime;
    if (data['cutoffTime'] is String) {
       final parts = (data['cutoffTime'] as String).split(':');
       if (parts.length == 2) {
          parsedTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
       }
    } else if (data['cutoffTime'] is Map) {
        // Handle map format if you stored it that way
    }

    return Show(
      id: doc.id,
      showName: data['listName'] ?? '', // Match Firestore field 'listName'
      date: parsedDate,
      address: data['address'] ?? '', // Match Firestore field
      state: data['state'] ?? '', // Match Firestore field
      latitude: (data['latitude'] as num?)?.toDouble(), // Handle potential num type
      longitude: (data['longitude'] as num?)?.toDouble(),
      numberOfSpots: data['numberOfSpots'] ?? 0,
      reservedSpots: List<String>.from(data['reservedSpots'] ?? []), // Keep if used
      bucketSpots: data['bucketSpots'] ?? false, // Keep if used
      numberOfWaitlistSpots: data['numberOfWaitlistSpots'] ?? 0, // Match Firestore field
      numberOfBucketSpots: data['numberOfBucketSpots'] ?? 0, // Match Firestore field
      waitList: List<String>.from(data['waitList'] ?? []), // Keep if used
      bucketNames: List<String>.from(data['bucketNames'] ?? []), // Keep if used
      cutoffDate: (data['cutoffDate'] as Timestamp?)?.toDate(), // Optional
      cutoffTime: parsedTime, // Optional
      userId: data['userId'] ?? '', // Match Firestore field
      createdAt: data['createdAt'] as Timestamp?, // Added
      spots: Map<String, dynamic>.from(data['spots'] ?? {}), // *** Get spots map ***
      signedUpUserIds: List<String>.from(data['signedUpUserIds'] ?? []), // Added
    );
  }

  // Convert Show object to Map for Firestore
  Map<String, dynamic> toMap() {
    // Handle TimeOfDay serialization (e.g., store as HH:mm string) - Optional
    String? timeString;
    if (cutoffTime != null) {
       timeString = "${cutoffTime!.hour.toString().padLeft(2,'0')}:${cutoffTime!.minute.toString().padLeft(2,'0')}";
    }

    return {
      'listName': showName, // Match Firestore field 'listName'
      'date': Timestamp.fromDate(date), // Store as Timestamp
      'address': address,
      'state': state,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'numberOfSpots': numberOfSpots,
      'reservedSpots': reservedSpots, // Keep if used
      'bucketSpots': bucketSpots, // Keep if used
      'numberOfWaitlistSpots': numberOfWaitlistSpots, // Match Firestore field
      'numberOfBucketSpots': numberOfBucketSpots, // Match Firestore field
      'waitList': waitList, // Keep if used
      'bucketNames': bucketNames, // Keep if used
      if (cutoffDate != null) 'cutoffDate': Timestamp.fromDate(cutoffDate!), // Optional
      if (timeString != null) 'cutoffTime': timeString, // Optional
      'userId': userId,
      // createdAt is set by server or on create
      'spots': spots, // *** Include spots map ***
      'signedUpUserIds': signedUpUserIds, // Include array
    };
  }
}
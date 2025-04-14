// lib/models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'spot.dart';

class Show {
  String showId;
  String showName;
  DateTime date;
  String location;
  String city;
  String state;
  int numberOfSpots; // Non-nullable
  List<String> reservedSpots;
  bool bucketSpots;
  int numberOfBucketSpots; // Non-nullable
  int waitListSpots; // Non-nullable
  List<Spot> waitList;
  List<Spot> spotsList;
  List<String> bucketNames;
  DateTime? cutoffDate;
  TimeOfDay? cutoffTime;

  Show({
    required this.showId,
    required this.showName,
    required this.date,
    required this.location,
    required this.city,
    required this.state,
    required this.numberOfSpots,
    this.reservedSpots = const [],
    this.bucketSpots = false,
    this.numberOfBucketSpots = 0,
    this.waitListSpots = 0,
    this.waitList = const [],
    this.spotsList = const [],
    this.bucketNames = const [],
    this.cutoffDate,
    this.cutoffTime,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'showId': showId,
      'showName': showName,
      'date': Timestamp.fromDate(date),
      'location': location,
      'city': city,
      'state': state,
      'numberOfSpots': numberOfSpots,
      'reservedSpots': reservedSpots,
      'bucketSpots': bucketSpots,
      'numberOfBucketSpots': numberOfBucketSpots,
      'waitListSpots': waitListSpots,
      'waitList': waitList.map((item) => item.toJson()).toList(),
      'spotsList': spotsList.map((item) => item.toJson()).toList(),
      'bucketNames': bucketNames,
      'cutoffDate': cutoffDate != null ? Timestamp.fromDate(cutoffDate!) : null,
      'cutoffTime': cutoffTime != null
          ? Timestamp.fromDate(DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
              cutoffTime!.hour,
              cutoffTime!.minute,
            ))
          : null,
    };
  }

  factory Show.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Debug prints to check data
    print('Document ID: ${doc.id}');
    print('Data: $data');

    return Show(
      showId: doc.id,
      showName: data['showName'] as String,
      date: (data['date'] as Timestamp).toDate(),
      location: data['location'] as String,
      city: data['city'] ?? '', // Handle null value for city
      state: data['state'] ?? '', // Handle null value for state
      numberOfSpots: data['numberOfSpots'] as int? ?? 0, // Provide a default value if null
      reservedSpots: List<String>.from(data['reservedSpots'] ?? []), // Handle null value for reservedSpots
      bucketSpots: data['bucketSpots'] as bool,
      numberOfBucketSpots: data['numberOfBucketSpots'] as int? ?? 0, // Provide a default value if null
      waitListSpots: data['waitListSpots'] as int? ?? 0, // Provide a default value if null
      waitList: (data['waitList'] as List<dynamic>? ?? []).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(), // Handle null value for waitList
      spotsList: (data['spotsList'] as List<dynamic>? ?? []).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(), // Handle null value for spotsList
      bucketNames: List<String>.from(data['bucketNames'] ?? []), // Handle null value for bucketNames
      cutoffDate: (data['cutoffDate'] as Timestamp?)?.toDate(),
      cutoffTime: data['cutoffTime'] != null
          ? TimeOfDay(
              hour: (data['cutoffTime'] as Timestamp).toDate().hour,
              minute: (data['cutoffTime'] as Timestamp).toDate().minute)
          : null,
    );
  }
}

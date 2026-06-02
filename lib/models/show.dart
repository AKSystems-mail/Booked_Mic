// models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/models/spot.dart';

class Show {
  final String? id;
  final String? userId; // Added userId field
  final String showName;
  final DateTime date;
  final String location;
  final String city;
  final String state;
  final int spots;
  final List<String> reservedSpots;
  final bool bucketSpots;
  final int waitListSpots;
  final List<Spot> waitList;
  final List<Spot> spotsList;
  final List<String> bucketNames;
  final DateTime? cutoffDate;
  final TimeOfDay? cutoffTime;

  Show({
    this.id,
    this.userId,
    required this.showName,
    required this.date,
    required this.location,
    required this.city,
    required this.state,
    required this.spots,
    required this.reservedSpots,
    required this.bucketSpots,
    required this.waitListSpots,
    required this.waitList,
    required this.spotsList,
    required this.bucketNames,
    this.cutoffDate,
    this.cutoffTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'showName': showName,
      'listName': showName, // Compatibility with 'Lists' collection
      'date': Timestamp.fromDate(date),
      'location': location,
      'city': city,
      'state': state,
      'spots': spots,
      'numberOfSpots': spots, // Compatibility
      'reservedSpots': reservedSpots,
      'bucketSpots': bucketSpots,
      'waitListSpots': waitListSpots,
      'numberOfWaitlistSpots': waitListSpots, // Compatibility
      'waitList': waitList.map((item) => item.toJson()).toList(),
      'spotsList': spotsList.map((item) => item.toJson()).toList(),
      'bucketNames': bucketNames,
      'cutoffDate': cutoffDate != null ? Timestamp.fromDate(cutoffDate!) : null,
      'cutoffTime': cutoffTime != null
          ? Timestamp.fromDate(DateTime(
              date.year,
              date.month,
              date.day,
              cutoffTime!.hour,
              cutoffTime!.minute,
            ))
          : null,
    };
  }

  factory Show.fromFirestore(DocumentSnapshot doc) {
    return Show.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  factory Show.fromMap(String id, Map<String, dynamic> data) {
    return Show(
      id: id,
      userId: data['userId'] as String?,
      showName: (data['showName'] ?? data['listName'] ?? 'Unnamed List') as String,
      date: (data['date'] as Timestamp).toDate(),
      location: (data['location'] ?? data['address'] ?? '') as String,
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      spots: (data['spots'] ?? data['numberOfSpots'] ?? 0) as int,
      reservedSpots: List<String>.from(data['reservedSpots'] ?? []),
      bucketSpots: (data['bucketSpots'] ?? (data['numberOfBucketSpots'] ?? 0) > 0),
      waitListSpots: (data['waitListSpots'] ?? data['numberOfWaitlistSpots'] ?? 0) as int,
      waitList: (data['waitList'] as List<dynamic>? ?? []).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(),
      spotsList: (data['spotsList'] as List<dynamic>? ?? []).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(),
      bucketNames: List<String>.from(data['bucketNames'] ?? []),
      cutoffDate: (data['cutoffDate'] as Timestamp?)?.toDate(),
      cutoffTime: data['cutoffTime'] != null
          ? TimeOfDay(
              hour: (data['cutoffTime'] as Timestamp).toDate().hour,
              minute: (data['cutoffTime'] as Timestamp).toDate().minute)
          : null,
    );
  }
}

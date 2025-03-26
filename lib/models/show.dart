// models/show.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myapp/models/spot.dart';

class Show {
  final String? id;
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
      'showName': showName,
      'date': Timestamp.fromDate(date),
      'location': location,
      'city': city,
      'state': state,
      'spots': spots,
      'reservedSpots': reservedSpots,
      'bucketSpots': bucketSpots,
      'waitListSpots': waitListSpots,
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
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Debug prints to check data
    print('Document ID: ${doc.id}');
    print('Data: $data');

    return Show(
      id: doc.id,
      showName: data['showName'] as String,
      date: (data['date'] as Timestamp).toDate(),
      location: data['location'] as String,
      city: data['city'] ?? '', // Handle null value for city
      state: data['state'] ?? '', // Handle null value for state
      spots: data['spots'] as int,
      reservedSpots: List<String>.from(data['reservedSpots'] ?? []), // Handle null value for reservedSpots
      bucketSpots: data['bucketSpots'] as bool,
      waitListSpots: data['waitListSpots'] as int,
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
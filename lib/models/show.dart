import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Spot {
  final String name;
  final String type;

  Spot({
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'type': type};
  }

  static Spot fromMap(Map<String, dynamic> map) {
    return Spot(
      name: map['name'],
      type: map['type'],
    );
  }
}

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
      'waitList': waitList.map((spot) => spot.toMap()).toList(),
      'spotsList': spotsList.map((spot) => spot.toMap()).toList(),
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

    return Show(
      id: doc.id,
      showName: data['showName'] as String,
      date: (data['date'] as Timestamp).toDate(),
      location: data['location'] as String,
      city: data['city'] as String,
      state: data['state'] as String,
      spots: data['spots'] as int,
      reservedSpots: List<String>.from(data['reservedSpots'] as List),
      bucketSpots: data['bucketSpots'] as bool,
      waitListSpots: data['waitListSpots'] as int,
      waitList: (data['waitList'] as List).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(),
      spotsList: (data['spotsList'] as List).map((item) => Spot.fromMap(item as Map<String, dynamic>)).toList(),
      bucketNames: List<String>.from(data['bucketNames'] as List),
      cutoffDate: (data['cutoffDate'] as Timestamp?)?.toDate(),
      cutoffTime: data['cutoffTime'] != null
          ? TimeOfDay.fromDateTime((data['cutoffTime'] as Timestamp).toDate())
          : null,
    );
  }
}
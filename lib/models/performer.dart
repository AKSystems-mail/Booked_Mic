// models/performer.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Performer {
  final String? id;
  final String performerName;
  final String defaultCity;

  Performer({
    this.id,
    required this.performerName,
    required this.defaultCity,
  });

  Map<String, dynamic> toMap() {
    return {
      'performerName': performerName,
      'defaultCity': defaultCity,
    };
  }

  factory Performer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Performer(
      id: doc.id,
      performerName: data['performerName'],
      defaultCity: data['defaultCity'],
    );
  }
}

// models/city.dart

class City {
  final String? id;
  final String cityName;

  City({
    this.id,
    required this.cityName,
  });

  Map<String, dynamic> toMap() {
    return {
      'cityName': cityName,
    };
  }

  factory City.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return City(
      id: doc.id,
      cityName: data['cityName'],
    );
  }
}
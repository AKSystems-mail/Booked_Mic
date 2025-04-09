// models/city.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class City {
  final String? id;
  final String name;
  final String state;

  City({
    this.id,
    required this.name,
    required this.state,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
    };
  }

  factory City.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return City(
      id: doc.id,
      name: data['name'],
      state: data['state'],
    );
  }
}

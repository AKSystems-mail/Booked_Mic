// models/performer.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Performer {
  final String? id;
  final String stageName;
  final String city;

  Performer({
    this.id,
    required this.stageName,
    required this.city,
  });

  String? get uid => id;

  Map<String, dynamic> toMap() {
    return {
      'stageName': stageName,
      'city': city,
    };
  }

  factory Performer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Performer(
      id: doc.id,
      stageName: data['stageName'] ?? '',
      city: data['city'] ?? '',
    );
  }
}

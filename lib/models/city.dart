import 'package:cloud_firestore/cloud_firestore.dart';

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
      cityName: data['cityName'] ?? '',
    );
  }
}

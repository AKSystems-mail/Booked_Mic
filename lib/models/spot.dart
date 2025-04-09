// models/spot.dart

class Spot {
  String name;
  String? performerId;
  bool confirmed;
  String type; // Add the type property

  Spot({
    required this.name,
    this.performerId,
    this.confirmed = false,
    required this.type, // Add the type property to the constructor
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'performerId': performerId,
      'confirmed': confirmed,
      'type': type, // Include the type property in the toJson method
    };
  }

  factory Spot.fromMap(Map<String, dynamic> map) {
    return Spot(
      name: map['name'] as String,
      performerId: map['performerId'] as String?,
      confirmed: map['confirmed'] as bool? ?? false,
      type: map['type'] as String, // Include the type property in the fromMap factory
    );
  }

  @override
  String toString() {
    return 'Spot{name: $name, performerId: $performerId, confirmed: $confirmed, type: $type}';
  }
}
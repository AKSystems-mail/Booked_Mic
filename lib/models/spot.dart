// models/spot.dart

class Spot {
  String name;
  String? performerId;
  bool confirmed;
  String type;

  Spot({
    required this.name,
    this.performerId,
    this.confirmed = false,
    this.type = 'regular',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'performerId': performerId,
      'userId': performerId, // Also include userId for compatibility
      'confirmed': confirmed,
      'type': type,
    };
  }

  factory Spot.fromMap(Map<String, dynamic> map) {
    return Spot(
      name: (map['name'] ?? map['performerName'] ?? 'Available') as String,
      performerId: (map['performerId'] ?? map['userId']) as String?,
      confirmed: map['confirmed'] as bool? ?? false,
      type: (map['type'] ?? 'regular') as String,
    );
  }

  @override
  String toString() {
    return 'Spot{name: $name, performerId: $performerId, confirmed: $confirmed, type: $type}';
  }
}

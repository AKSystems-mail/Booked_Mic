// models/signup.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup {
  final String? id;
  final String performerName;
  final DateTime signupTime;
  final int position;
  final bool isFinished;
  final bool isBucket;
  final bool isWaitlist;

  Signup({
    this.id,
    required this.performerName,
    required this.signupTime,
    required this.position,
    required this.isFinished,
    required this.isBucket,
    required this.isWaitlist,
  });

  Map<String, dynamic> toMap() {
    return {
      'performerName': performerName,
      'signupTime': signupTime,
      'position': position,
      'isFinished': isFinished,
      'isBucket': isBucket,
      'isWaitlist': isWaitlist,
    };
  }

  factory Signup.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Signup(
      id: doc.id,
      performerName: data['performerName'],
      signupTime: (data['signupTime'] as Timestamp).toDate(),
      position: data['position'],
      isFinished: data['isFinished'],
      isBucket: data['isBucket'],
      isWaitlist: data['isWaitlist'],
    );
  }
}
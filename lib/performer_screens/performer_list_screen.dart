// performer_screens/performer_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PerformerListScreen extends StatelessWidget {
  final String showId;
  final String performerId;

  const PerformerListScreen({super.key, required this.showId, required this.performerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performer List')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('shows').doc(showId).collection('signups').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> signups = snapshot.data!.docs;
          int performerIndex = signups.indexWhere((doc) => doc.id == performerId);

          return ListView.builder(
            itemCount: signups.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(signups[index]['performerName']),
                trailing: index == performerIndex ? const Text('You') : null,
              );
            },
          );
        },
      ),
    );
  }
}
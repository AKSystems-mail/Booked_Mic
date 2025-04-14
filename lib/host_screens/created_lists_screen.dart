// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Import Provider
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:intl/intl.dart';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:screenshot/screenshot.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';

// Import necessary screens & PROVIDER
import 'list_setup_screen.dart';
// import '../role_selection_screen.dart';
// import 'show_list_screen.dart';
// import 'edit_list_screen.dart';
import 'package:myapp/providers/firestore_provider.dart'; // Import FirestoreProvider

// --- Top Level Helper Functions (_showOptionsDialog, _downloadQRCode) remain the same ---
Future<void> _showOptionsDialog(BuildContext context, String listId, String listName, String? qrCodeData, Timestamp? date) async { /* ... */ }
Future<void> _downloadQRCode(BuildContext context, String qrCodeData, String listName, DateTime date) async { /* ... */ }
// --- End Helper Functions ---


class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({super.key});

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _switchRole(BuildContext context) async { /* ... */ }

  // --- Delete Confirmation Dialog ---
  Future<void> _showDeleteConfirmationDialog(BuildContext context, String listId, String listName) async {
     final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
           return AlertDialog(
              title: Text('Delete List?'),
              content: Text('Are you sure you want to permanently delete the list "$listName"? This cannot be undone.'),
              actions: <Widget>[
                 TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
                 TextButton(child: Text('Delete', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(dialogContext).pop(true)),
              ],
           );
        }
     );

     if (confirm == true && context.mounted) {
        try {
           // Use read as it's a one-off action
           await context.read<FirestoreProvider>().deleteList(listId);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List "$listName" deleted.')));
        } catch (e) {
           print("Error deleting list: $e");
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting list: $e'), backgroundColor: Colors.red));
        }
     }
  }
  // --- End Delete Dialog ---


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    if (currentUserId == null) { /* ... Redirect logic ... */ }

    // Access provider here if needed for delete action context
    // final firestoreProvider = context.read<FirestoreProvider>(); // Use read if only for actions

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup ... */ ),
      body: Container(
        // ... gradient ...
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            // ... (loading, error, empty checks) ...
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven’t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.85),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>?;
                final String docId = doc.id;

                if (listData == null) { /* ... Error Card ... */ }

                final String? qrCodeData = docId;
                final Timestamp? date = listData?['date'] as Timestamp?;
                final String listName = listData?['listName'] ?? 'Unnamed List';
                // ... (Spot count calculation) ...

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  // --- Wrap Card with GestureDetector ---
                  child: GestureDetector(
                     onLongPress: () => _showDeleteConfirmationDialog(context, docId, listName),
                     child: Card(
                       color: Colors.white.withOpacity(0.9), elevation: 3,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), clipBehavior: Clip.antiAlias,
                       child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column( /* ... Card content ... */ )
                          ),
                       ),
                     ),
                  ),
                  // --- End GestureDetector ---
                );
              },
            );
          },
        ),
      ),
       floatingActionButton: FadeInUp(
        delay: Duration(milliseconds: 500),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => ListSetupScreen())),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          tooltip: 'Create New List',
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
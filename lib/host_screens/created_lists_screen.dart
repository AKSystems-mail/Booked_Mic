// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';
import 'package:flutter/services.dart';

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';
import 'package:myapp/providers/firestore_provider.dart';

// --- Top Level Helper Functions ---

// --- MODIFIED Options Dialog ---
Future<void> _showOptionsDialog(BuildContext context, String listId,
    String listName, String? qrCodeData, Timestamp? date) async {
  // Use themed colors (access theme via context)
  final Color primaryColor = Theme.of(context).primaryColor;
  final Color appBarColor = Colors.blue.shade400; // Or get from theme
  final Color deleteColor = Colors.red.shade700; // Specific color for delete

  // Check mounted before showing dialog
  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // Renamed context for clarity
      return AlertDialog(
        backgroundColor: Colors.white.withAlpha((255 * 0.95).round()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(listName,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: Text('What would you like to do with this list?',
            style: TextStyle(color: Colors.black87)),
        actionsAlignment: MainAxisAlignment.center, // Center buttons
        // Use Column for better button layout if many options
        actions: <Widget>[
          TextButton.icon(
            icon: Icon(Icons.visibility_outlined, color: appBarColor),
            label: Text('Show', style: TextStyle(color: appBarColor)),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close this dialog
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ShowListScreen(listId: listId)));
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.edit_outlined, color: appBarColor),
            label: Text('Edit', style: TextStyle(color: appBarColor)),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close this dialog
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditListScreen(listId: listId)));
            },
          ),
          if (qrCodeData != null && date != null)
            TextButton.icon(
              icon: Icon(Icons.download_outlined, color: appBarColor),
              label: Text('Download QR',
                  style: TextStyle(color: appBarColor)), // Shortened label
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close this dialog
                await _downloadQRCode(
                    context, qrCodeData, listName, date.toDate());
              },
            ),
          // --- Added Delete Button ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0), // Add space above delete
            child: TextButton.icon(
              icon: Icon(Icons.delete_forever_outlined, color: deleteColor),
              label: Text('Delete List', style: TextStyle(color: deleteColor)),
              onPressed: () async {
                Navigator.of(dialogContext)
                    .pop(); // Close the options dialog FIRST

                // Show nested confirmation dialog
                final bool? confirmDelete = await showDialog<bool>(
                    context: context, // Use original screen context
                    builder: (BuildContext confirmCtx) {
                      return AlertDialog(
                        title: Text('Confirm Delete'),
                        content: Text(
                            'Permanently delete "$listName"?\nThis cannot be undone.'),
                        actions: [
                          TextButton(
                            child: Text('Cancel'),
                            onPressed: () =>
                                Navigator.of(confirmCtx).pop(false),
                          ),
                          TextButton(
                            child: Text('DELETE',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.of(confirmCtx).pop(true),
                          ),
                        ],
                      );
                    });

                // If deletion confirmed, call provider action
                if (confirmDelete == true && context.mounted) {
                  // Check mounted again
                  try {
                    await context.read<FirestoreProvider>().deleteList(listId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('List "$listName" deleted.')));
                    }
                  } catch (e) {
                    // print("Error deleting list: $e"); // Commented out
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error deleting list: $e'),
                          backgroundColor: Colors.red));
                    }
                  }
                }
              },
            ),
          ),
          // --- End Added Delete Button ---
        ],
      );
    },
  );
}

// Keep _downloadQRCode
Future<void> _downloadQRCode(BuildContext context, String qrCodeData,
    String listName, DateTime date) async {
  // ... (Implementation remains the same) ...
}

// --- REMOVED _showDeleteConfirmationDialog ---
// Future<void> _showDeleteConfirmationDialog(BuildContext context, String listId, String listName) async { /* ... */ }
// --- End REMOVED ---

// --- End Helper Functions ---

class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({super.key});

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;

    if (currentUserId == null) {/* ... Redirect logic ... */}

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Created Lists'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _switchRole(context),
              icon: Icon(Icons.sync_alt, size: 24.0, color: Colors.white),
              label: Text('Switch Role',
                  style: TextStyle(fontSize: 14.0, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Lists')
              .where('userId', isEqualTo: currentUserId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // ... (loading, error, empty checks) ...
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return Center(
                  child: Text('You haven’t created any lists yet.',
                      style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 0.85),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>? ?? {};
                final String docId = doc.id;
                final String qrCodeData = docId;
                final Timestamp? date = listData['date'] as Timestamp?;
                final String listName = listData['listName'] ?? 'Unnamed List';
                final spotsMap =
                    listData['spots'] as Map<String, dynamic>? ?? {};
                int filledRegular = 0;
                int filledWaitlist = 0;
                int filledBucket = 0;
                spotsMap.forEach((key, value) {
                  if (value is Map) {
                    if (key.startsWith('W')) {
                      filledWaitlist++;
                    } else if (key.startsWith('B')) {
                      filledBucket++;
                    } else if (int.tryParse(key) != null) {
                      filledRegular++;
                    }
                  }
                });
                final int totalRegular = listData['numberOfSpots'] ?? 0;
                final int totalWaitlist =
                    listData['numberOfWaitlistSpots'] ?? 0;
                final int totalBucket = listData['numberOfBucketSpots'] ?? 0;

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  // --- REMOVED GestureDetector ---
                  child: Card(
                    color: Colors.white.withAlpha((255 * 0.9).round()),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      // Keep InkWell for tap
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showOptionsDialog(context, docId, listName,
                          qrCodeData, date), // Calls options dialog
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(listName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  SizedBox(height: 4),
                                  Text(listData['address'] ?? 'No Address',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                      maxLines: 1,
                                      overflow: TextOverflow
                                          .ellipsis), /* Optional QR */
                                ]),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (totalRegular > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                            'Regular: $filledRegular/$totalRegular',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13))),
                                  if (totalWaitlist > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                            'Waitlist: $filledWaitlist/$totalWaitlist',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13))),
                                  if (totalBucket > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                            'Bucket: $filledBucket/$totalBucket',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13)))
                                ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // --- END REMOVED GestureDetector ---
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FadeInUp(/* ... FAB ... */),
      delay: Duration(milliseconds: 500),
      child: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => ListSetupScreen())),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        tooltip: 'Create New List',
        child: Icon(Icons.add),
      ),
    );
  }
}

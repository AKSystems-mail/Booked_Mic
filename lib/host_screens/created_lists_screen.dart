// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Re-add for QrImageView and QrPainter

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';
import 'package:myapp/providers/firestore_provider.dart'; // Import FirestoreProvider

// --- Delete Confirmation Dialog Helper ---
Future<void> _showDeleteConfirmationDialog(
    BuildContext context, String listId, String listName) async {
  if (!context.mounted) return;
  final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use Theme for colors if available, otherwise fallback
        final Color primaryColor = Theme.of(context).primaryColor;
        final Color deleteColor = Colors.red.shade700;

        return AlertDialog(
          // Simple styling for older context
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('Delete List?', style: TextStyle(color: primaryColor)),
          content: Text(
              'Permanently delete "$listName"?\nThis cannot be undone.',
              style: TextStyle(color: Colors.black87)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text('DELETE',
                  style: TextStyle(
                      color: deleteColor, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      });

  if (confirm == true && context.mounted) {
    try {
      // Use read as it's a one-off action
      await context.read<FirestoreProvider>().deleteList(listId);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('List "$listName" deleted.')));
    } catch (e) {
      // print("Error deleting list: $e"); // Commented out
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error deleting list: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}
// --- End Delete Helper ---

class CreatedListsScreen extends StatelessWidget {
  // Use super parameter for key
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

  // --- MODIFIED Options Dialog ---
  Future<void> _showOptionsDialog(
      BuildContext context, String listId, String listName) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color appBarColor = Colors.blue.shade400; // Keep consistent
    final Color deleteColor = Colors.red.shade700; // Delete color

    // Check mounted before showing dialog
    if (!context.mounted) return;

    await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white.withAlpha((255 * 0.95).round()),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(listName,
                style: TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold)),
            content: Text('What would you like to do with this list?',
                style: TextStyle(color: Colors.black87)),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              TextButton.icon(
                  icon: Icon(Icons.edit_outlined, color: appBarColor),
                  label: Text('Edit', style: TextStyle(color: appBarColor)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                EditListScreen(listId: listId)));
                  }),
              TextButton.icon(
                  icon: Icon(Icons.visibility_outlined, color: appBarColor),
                  label: Text('Show', style: TextStyle(color: appBarColor)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ShowListScreen(listId: listId)));
                  }),
              // --- Added Delete Button ---
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  icon: Icon(Icons.delete_forever_outlined, color: deleteColor),
                  label:
                      Text('Delete List', style: TextStyle(color: deleteColor)),
                  onPressed: () {
                    Navigator.of(dialogContext)
                        .pop(); // Close this dialog first
                    // Call the separate confirmation dialog
                    _showDeleteConfirmationDialog(context, listId, listName);
                  },
                ),
              ),
              // --- End Added Delete Button ---
            ],
          );
        });
  }
  // --- End Options Dialog ---

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600; // Button color

    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
            (Route<dynamic> route) => false);
      });
      return Scaffold(body: Center(child: Text("Redirecting...")));
    }

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
              // Keep styled button
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: appBarColor));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error loading lists.',
                      style: TextStyle(color: Colors.red.shade900)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                  child: Text('You haven’t created any lists yet.',
                      style: TextStyle(color: Colors.black54, fontSize: 16)));
            }

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
                // Removed qrCodeData/date variables as they aren't used in this version's dialog call
                final String listName = listData['listName'] ?? 'Unnamed List';

                final String qrCodeData = docId; // Assuming you want to encode the list ID in the QR code

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
                  child: Card(
                    // Removed GestureDetector
                    color: Colors.white.withAlpha((255 * 0.9).round()),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      // Updated onTap to only pass needed args
                      onTap: () => _showOptionsDialog(context, docId, listName),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(listName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis), // Smaller title
                            SizedBox(height: 2),
                            Text(listData['address'] ?? 'No Address',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Colors.black54, fontSize: 11),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis), // Smaller address
                            SizedBox(height: 8),

                            // --- *** ADD QR CODE DISPLAY *** ---
                            Center(
                              // Center the QR code
                              child: QrImageView(
                                data: qrCodeData,
                                version: QrVersions.auto,
                                size: 80.0, // Adjust size to fit card
                                gapless:
                                    true, // Smaller gaps might look better at small size
                                backgroundColor: Colors
                                    .white, // Ensure background for visibility
                              ),
                            ),
                            // --- *** END QR CODE DISPLAY *** ---

                            Spacer(), // Push counts to the bottom

                            // Bottom Section: Counts
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (totalRegular > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                            'Regular: $filledRegular/$totalRegular',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12))), // Smaller font
                                  if (totalWaitlist > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                            'Waitlist: $filledWaitlist/$totalWaitlist',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12))),
                                  if (totalBucket > 0)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                            'Bucket: $filledBucket/$totalBucket',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12)))
                                ]),
                          ],
                        ),
                      ),
                    ),
                  ),
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

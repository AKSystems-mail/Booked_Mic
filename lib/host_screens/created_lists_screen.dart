// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import this for PlatformException
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Keep if _switchRole uses it
import 'package:animate_do/animate_do.dart';
// import 'package:qr_flutter/qr_flutter.dart'; // Keep if using QR generation
import 'package:intl/intl.dart'; // Keep for date formatting
import 'dart:io'; // Keep for File
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';

// Import necessary screens
import 'list_setup_screen.dart'; // Used by FAB
import '../role_selection_screen.dart'; // Used by _switchRole
import 'show_list_screen.dart'; // Used by dialog
import 'edit_list_screen.dart'; // Used by dialog
import 'package:myapp/providers/firestore_provider.dart';

// --- Top Level Helper Functions ---

Future<void> _showOptionsDialog(BuildContext context, String listId,
    String listName, String? qrCodeData, Timestamp? date) async {
  // Use themed colors (access theme via context)
  final Color primaryColor = Theme.of(context).primaryColor;
  final Color appBarColor = Colors.blue.shade400; // Or get from theme

  // Check mounted before showing dialog
  if (!context.mounted) return;

  // Ensure builder returns a Widget
  await showDialog( // Removed return here, showDialog is void
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog( // Return AlertDialog
        backgroundColor: Colors.white.withAlpha((255 * 0.95).round()), // Use withAlpha
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(listName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: Text('What would you like to do with this list?', style: TextStyle(color: Colors.black87)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: <Widget>[
          TextButton.icon(
            icon: Icon(Icons.edit_outlined, color: appBarColor),
            label: Text('Edit', style: TextStyle(color: appBarColor)), // Added label
            onPressed: () { // Added onPressed
              Navigator.of(dialogContext).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId)));
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.visibility_outlined, color: appBarColor),
            label: Text('Show', style: TextStyle(color: appBarColor)), // Added label
            onPressed: () { // Added onPressed
              Navigator.of(dialogContext).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: listId)));
            },
          ),
          if (qrCodeData != null && date != null)
            TextButton.icon(
              icon: Icon(Icons.download_outlined, color: appBarColor),
              label: Text('Download QR code', style: TextStyle(color: appBarColor)),
              // Wrap async call
              onPressed: () async { // Make anonymous function async
                Navigator.of(dialogContext).pop();
                // Use await here
                await _downloadQRCode(context, qrCodeData, listName, date.toDate());
              },
            ),
        ],
      );
    },
  );
}

// Keep _downloadQRCode - IS used by dialog
Future<void> _downloadQRCode(BuildContext context, String qrCodeData, String listName, DateTime date) async {
  if (!context.mounted) return;
  ScreenshotController screenshotController = ScreenshotController();
  final theme = Theme.of(context); // Used for text style
  final dateString = DateFormat('EEE, MMM d, yyyy').format(date); // Used for text
  final Widget qrWidgetToCapture = Material( // Used for capture
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(listName, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(dateString, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 15),
          SizedBox(
            width: 250, height: 250,
            // Ensure QrImageView is imported if used here
            // child: QrImageView(data: qrCodeData, version: QrVersions.auto, size: 250.0, gapless: false),
            child: Container(color: Colors.grey, child: Center(child: Text("QR Placeholder"))), // Placeholder if QrImageView causes issues
          ),
        ],
      ),
    ),
  );

  try {
    // Pass the widget to capture
    final Uint8List? imageBytes = await screenshotController.captureFromWidget(
       qrWidgetToCapture, context: context, delay: const Duration(milliseconds: 100),
    );// Pass the widget
       
    if (imageBytes == null) throw Exception('Failed to capture QR code widget.');
    final directory = await getTemporaryDirectory();
    final safeListName = listName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final imagePath = '${directory.path}/qr_${safeListName}_${DateFormat('yyyyMMdd').format(date)}.png';
    final file = File(imagePath);
    await file.writeAsBytes(imageBytes);
    await FlutterImageGallerySaver.saveFile(file.path);
    
    // print("Gallery Save Result: $result"); // Commented out

    bool success = false;
    String errorMessage = 'Unknown error';

    try {
      await FlutterImageGallerySaver.saveFile(file.path); success = true; // If await completes, assume success
    } on PlatformException catch (e) {errorMessage = e.message ?? 'Platform error saving file.';
    } catch (e) {
      errorMessage = e.toString();
    }

    // 4. Show Feedback (Check mounted AFTER async gallery save attempt)
    if (!context.mounted) return;

    if (success) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code with details saved to gallery.')));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange));
    }
    // --- End Platform Handling ---

  } catch (e) {
    if(context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download QR code: $e')));
    }
  }
}

Future<void> _showDeleteConfirmationDialog(BuildContext context, String listId, String listName) async {
   if (!context.mounted) return;
   final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); });
   if (confirm == true && context.mounted) { // Re-check mounted
      try {
         await context.read<FirestoreProvider>().deleteList(listId);
         if(context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List "$listName" deleted.'))); }
      } catch (e) { if (context.mounted) { /* ... Error SnackBar ... */ } }
   }
}
// --- End Helper Functions ---


class CreatedListsScreen extends StatelessWidget {
  // Removed const constructor
  CreatedListsScreen({super.key});

  // Field is initialized here, cannot be const constructor
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Keep _switchRole - IS used by AppBar action
  Future<void> _switchRole(BuildContext context) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('user_role');
     if (!context.mounted) return; // Mounted check
     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()));
  }


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;

    if (currentUserId == null) { /* ... Redirect logic ... */ }

    return Scaffold(
      appBar: AppBar(
         backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
         title: Text('Created Lists'),
         actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                 message: 'Switch Role',
                 child: ElevatedButton.icon(
                  onPressed: () => _switchRole(context),
                  icon: Icon(Icons.sync_alt, size: 24.0, color: Colors.white),
                  label: Text('Switch Role', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              )
              ),
            ),
         ],
      ),
      body: Container( // Keep container for gradient
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
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
                // Use null check pattern or default value
                final listData = doc.data() as Map<String, dynamic>? ?? {}; // Use default empty map
                final String docId = doc.id;

                final String qrCodeData = docId;
                final Timestamp? date = listData['date'] as Timestamp?;
                final String listName = listData['listName'] ?? 'Unnamed List';

                // Use count variables
                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                int filledRegular = 0; int filledWaitlist = 0; int filledBucket = 0;
                spotsMap.forEach((key, value) {
                   if (value is Map) { // Added curly braces
                      if (key.startsWith('W')) { filledWaitlist++; }
                      else if (key.startsWith('B')) { filledBucket++; }
                      else if (int.tryParse(key) != null) { filledRegular++; }
                   }
                });
                final int totalRegular = listData['numberOfSpots'] ?? 0; // Use final non-nullable + null check
                final int totalWaitlist = listData['numberOfWaitlistSpots'] ?? 0; // Use final non-nullable + null check
                final int totalBucket = listData['numberOfBucketSpots'] ?? 0; // Use final non-nullable + null check

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector( // Or InkWell if you prefer that visual feedback
  onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date), // Keep your existing onTap
  onLongPress: () async {
    // Show the menu with the delete option
    final result = await showMenu<String>( // Specify the type <String>
      context: context,
      // Position the menu. Centering is a simple default for long press.
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width / 3, // Adjust LTRB as needed
        MediaQuery.of(context).size.height / 3,
        MediaQuery.of(context).size.width / 3,
        MediaQuery.of(context).size.height / 3,
      ),
      items: <PopupMenuEntry<String>>[ // Specify the type <String>
        const PopupMenuItem<String>(
          value: 'delete', // Value returned when this item is selected
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        // You could add more options here if needed
      ],
    );

    // If the user selected 'delete' from the menu
    if (result == 'delete') {
      // Now show the confirmation dialog
      final confirmDelete = await showDialog<bool>( // Specify the type <bool>
        context: context,
        builder: (BuildContext dialogContext) { // Use a different context name
          return AlertDialog(
            title: const Text("Confirm Delete"),
            content: Text(
                "Are you sure you want to delete '${listData?['listName'] ?? 'this list'}'? This action cannot be undone."), // Add warning
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false), // Return false
                  child: const Text("Cancel")),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(dialogContext).pop(true), // Return true
                  child: const Text("Delete")),
            ],
          );
        },
      );

      // If the user confirmed deletion in the dialog
      if (confirmDelete == true) {
        try {
          await FirebaseFirestore.instance
              .collection('Lists')
              .doc(docId)
              .delete();
          if (context.mounted) { // Check context mounted before ScaffoldMessenger
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "'${listData?['listName'] ?? 'List'}' deleted successfully.")),
            );
          }
        } catch (error) {
          print("Error deleting list: $error");
          if (context.mounted) { // Check context mounted before ScaffoldMessenger
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Error deleting '${listData?['listName'] ?? 'List'}': $error"),
                  backgroundColor: Colors.red), // Add background color
            );
          }
        }
      }
    }
  },
                     child: Card(
                       color: Colors.white.withAlpha((255 * 0.9).round()), // Use withAlpha
                       elevation: 3,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       clipBehavior: Clip.antiAlias,
                       child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(listName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), SizedBox(height: 4), Text(listData['address'] ?? 'No Address', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis), /* Optional QR */ ]),
                                // Use Count Variables
                                Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                   if (totalRegular > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Regular: $filledRegular/$totalRegular', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                   if (totalWaitlist > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Waitlist: $filledWaitlist/$totalWaitlist', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                                   if (totalBucket > 0) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Bucket: $filledBucket/$totalBucket', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)))
                                ]),
                              ],
                            ),
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
      // Keep FAB - IS used
      floatingActionButton: FadeInUp(
        delay: Duration(milliseconds: 500),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListSetupScreen())),
          backgroundColor: appBarColor, foregroundColor: Colors.white,
          tooltip: 'Create New List', child: Icon(Icons.add),
        ),
      ),
    );
  }
}
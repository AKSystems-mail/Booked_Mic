// lib/host_screens/created_lists_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Used by _switchRole
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Used by _downloadQRCode and potentially Card UI
import 'package:intl/intl.dart'; // Used by _downloadQRCode
import 'package:screenshot/screenshot.dart'; // Used by _downloadQRCode

import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter/services.dart'; // Used for PlatformException in _downloadQRCode

// Import necessary screens
import 'list_setup_screen.dart'; // Used by FAB
import '../role_selection_screen.dart'; // Used by _switchRole
import 'show_list_screen.dart'; // Used by dialog
import 'edit_list_screen.dart'; // Used by dialog
import 'package:myapp/providers/firestore_provider.dart'; // Used by dialog actions

// --- Top Level Helper Functions ---

Future<void> _showOptionsDialog(BuildContext context, String listId,
    String listName, String qrCodeData, Timestamp? date) async { // Made qrCodeData non-nullable
  final Color primaryColor = Theme.of(context).primaryColor;
  final Color appBarColor = Colors.blue.shade400;

  // Check mounted before showing dialog
  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // Ensure builder returns a Widget
      return AlertDialog(
        backgroundColor: Colors.white.withAlpha((255 * 0.95).round()), // Use withAlpha
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(listName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: Text('What would you like to do with this list?', style: TextStyle(color: Colors.black87)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: <Widget>[
          TextButton.icon(
            icon: Icon(Icons.visibility_outlined, color: appBarColor),
            label: Text('Show', style: TextStyle(color: appBarColor)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: listId)));
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.edit_outlined, color: appBarColor),
            label: Text('Edit', style: TextStyle(color: appBarColor)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId)));
            },
          ),
          // Check date is not null before showing download
          if (date != null)
            TextButton.icon(
              icon: Icon(Icons.download_outlined, color: appBarColor),
              label: Text('Download QR', style: TextStyle(color: appBarColor)),
              // Wrap async call
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Pass non-nullable qrCodeData and converted date
                await _downloadQRCode(context, qrCodeData, listName, date.toDate());
              },
            ),
          TextButton.icon(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
            label: Text('Delete List', style: TextStyle(color: Colors.red.shade700)),
            onPressed: () async {
               Navigator.of(dialogContext).pop();
               // Pass context for delete confirmation
               await _showDeleteConfirmationDialog(context, listId, listName);
            },
          ),
        ],
      );
    },
  );
}

// Keep _downloadQRCode - IS used by dialog
Future<void> _downloadQRCode(BuildContext context, String qrCodeData,
    String listName, DateTime date) async {
  if (!context.mounted) return;

  ScreenshotController screenshotController = ScreenshotController();
  Theme.of(context);
  DateFormat('EEE, MMM d, yyyy').format(date);

  // Widget to capture (includes QR, Title, Date)
  final Widget qrWidgetToCapture = Material( /* ... Widget Definition ... */ );

  try {
    // 1. Capture Widget to Bytes
    final Uint8List? imageBytes = await screenshotController.captureFromWidget(
      qrWidgetToCapture, context: context, delay: const Duration(milliseconds: 100),
    );
    if (imageBytes == null) throw Exception('Failed to capture QR code widget.');

    // 2. Save Bytes to Temporary File (Still needed for gallery_saver)
    final directory = await getTemporaryDirectory();
    final safeListName = listName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    // Use a unique name to avoid potential caching issues if user downloads multiple times quickly
    final String tempFilename = 'qr_${safeListName}_${DateTime.now().millisecondsSinceEpoch}.png';
    final imagePath = '${directory.path}/$tempFilename';
    final file = File(imagePath);
    await file.writeAsBytes(imageBytes);
    print("Saved temp file to: ${file.path}"); // Debugging print

    // --- 3. Save Temporary File to Gallery using gallery_saver ---
    bool? success = false; // gallery_saver returns bool?
    String errorMessage = 'Failed to save to gallery.';

    try {
      success = await GallerySaver.saveImage(
          file.path,
          albumName: "Booked Mic Lists" // Optional: Specify album name
      );
      // print("Gallery Save Result: $success"); // Commented out
      if (success == true) {
         errorMessage = ''; // Clear default error if successful
      } else {
         errorMessage = 'Saving to gallery failed (plugin returned false/null).';
      }
    } on PlatformException catch (e) { // Catch specific platform errors
      errorMessage = e.message ?? 'Platform error saving file.';
      // print("Gallery Save PlatformException: $e"); // Commented out
      success = false;
    } catch (e) { // Catch other potential errors during save
      errorMessage = e.toString();
      // print("Gallery Save General Error: $e"); // Commented out
      success = false;
    }
    // --- End Save Logic ---

    // 4. Show Feedback
    if (!context.mounted) return; // Re-check mounted

    if (success == true) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code with details saved to gallery.')));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange));
    }

    // 5. Clean up temporary file (optional but good practice)
    try {
       if (await file.exists()) {
          await file.delete();
          print("Deleted temp file: ${file.path}");
       }
    } catch (e) {
       print("Error deleting temp QR file: $e");
    }

  } catch (e) { // Catch errors from capture or file writing
    // print("Error downloading QR code: $e"); // Commented out
    if(context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate/download QR code: $e')));
    }
  }
}


Future<void> _showDeleteConfirmationDialog(BuildContext context, String listId, String listName) async {
   if (!context.mounted) return;
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
         ); // Return AlertDialog
      }
   );

   // Use mounted check correctly
   if (confirm == true) {
      // Check mounted *before* async gap
      if (!context.mounted) return;
      // Capture context dependent objects before await
      final provider = context.read<FirestoreProvider>();
      final messenger = ScaffoldMessenger.of(context);
      try {
         await provider.deleteList(listId);
         // Use captured messenger
         messenger.showSnackBar(SnackBar(content: Text('List "$listName" deleted.')));
      } catch (e) {
         // print("Error deleting list: $e"); // Commented out
         // Use captured messenger
         messenger.showSnackBar(SnackBar(content: Text('Error deleting list: $e'), backgroundColor: Colors.red));
      }
   }
}
// --- End Helper Functions ---


class CreatedListsScreen extends StatelessWidget {
  // Removed const constructor
  CreatedListsScreen({super.key});

  // Make currentUserId final
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Keep _switchRole - IS used by AppBar action
  Future<void> _switchRole(BuildContext context) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('user_role');
     if (!context.mounted) return;
     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()));
  }


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final firestoreProvider = context.read<FirestoreProvider>(); // Use read if only needed for actions

    if (currentUserId == null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()), (Route<dynamic> route) => false);
       });
       return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
         backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
         title: Text('Created Lists'),
         actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _switchRole(context),
                icon: Icon(Icons.sync_alt, size: 24.0, color: Colors.white),
                label: Text('Switch Role', style: TextStyle(fontSize: 14.0, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 2,
                ),
              ),
            ),
         ],
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
            if (snapshot.hasError) return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven’t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.8),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>? ?? {};
                final String docId = doc.id;
                // Define non-nullable qrCodeData
                final String qrCodeData = docId;
                final Timestamp? date = listData['date'] as Timestamp?;
                final String listName = listData['listName'] ?? 'Unnamed List';

                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                // Use count variables
                int filledRegular = 0; int filledWaitlist = 0;
                spotsMap.forEach((key, value) {
                   if (value is Map) { // Added curly braces
                      if (key.startsWith('W')) { filledWaitlist++; }
                      else if (int.tryParse(key) != null) { filledRegular++; }
                   }
                });
                final int totalRegular = listData['numberOfSpots'] ?? 0;
                final int totalWaitlist = listData['numberOfWaitlistSpots'] ?? 0;
                final int totalBucketSpots = listData['numberOfBucketSpots'] ?? 0;

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                     onLongPress: () => _showDeleteConfirmationDialog(context, docId, listName),
                     child: Card(
                       color: Colors.white.withAlpha((255 * 0.9).round()), // Use withAlpha
                       elevation: 3,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       clipBehavior: Clip.antiAlias,
                       child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          // Pass defined variables
                          onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(listName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 2), Text(listData['address'] ?? 'No Address', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis), SizedBox(height: 6), Center( child: QrImageView( data: qrCodeData, version: QrVersions.auto, size: 65.0, gapless: true, backgroundColor: Colors.white, errorStateBuilder: (cxt, err) => Text("QR Error", style: TextStyle(fontSize: 10, color: Colors.red))), ), ]),
                                Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                   if (totalRegular > 0) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('Regular: $filledRegular/$totalRegular', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                                   if (totalWaitlist > 0) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('Waitlist: $filledWaitlist/$totalWaitlist', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
                                   if (totalBucketSpots > 0)
                                      FutureBuilder<int>(
                                         future: firestoreProvider.getBucketSignupCount(docId),
                                         builder: (context, countSnapshot) {
                                            int bucketCount = countSnapshot.data ?? 0;
                                            Widget bucketText = Text('Bucket Signups: $bucketCount', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12));
                                            if (countSnapshot.connectionState == ConnectionState.waiting) { bucketText = Text('Bucket Signups: ...', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, fontStyle: FontStyle.italic)); }
                                            else if (countSnapshot.hasError) { bucketText = Text('Bucket Signups: Err', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.red.shade300)); }
                                            return Padding(padding: const EdgeInsets.only(top: 2.0), child: bucketText);
                                         },
                                      ),
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
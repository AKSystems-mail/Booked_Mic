// lib/host_screens/created_lists_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
// Removed unused import: import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart';

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';
import 'package:myapp/providers/firestore_provider.dart';

// --- Top Level Helper Functions ---

Future<void> _showOptionsDialog(BuildContext context, String listId,
    String listName, String? qrCodeData, Timestamp? date) async {
  final Color primaryColor = Theme.of(context).primaryColor;
  final Color appBarColor = Colors.blue.shade400;

  if (!context.mounted) return;

  // Ensure builder returns a Widget
  return await showDialog( // Added return
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog( // Return AlertDialog
        backgroundColor: Colors.white.withAlpha((255 * 0.95).round()), // Use withAlpha
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(listName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: Text('What would you like to do with this list?', style: TextStyle(color: Colors.black87)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: <Widget>[
          TextButton.icon( /* ... Edit Button ... */ ),
          TextButton.icon( /* ... Show Button ... */ ),
          if (qrCodeData != null && date != null)
            TextButton.icon(
              icon: Icon(Icons.download_outlined, color: appBarColor),
              label: Text('Download QR code', style: TextStyle(color: appBarColor)),
              // Wrap async call
              onPressed: () async {
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
Future<void> _downloadQRCode(BuildContext context, String qrCodeData,
    String listName, DateTime date) async {
  // ... (function body remains the same, remove unused theme/dateString/qrWidgetToCapture) ...
   if (!context.mounted) return;
   ScreenshotController screenshotController = ScreenshotController();
   // final theme = Theme.of(context); // Unused
   // final dateString = DateFormat('EEE, MMM d, yyyy').format(date); // Unused
   // final Widget qrWidgetToCapture = Material(...); // Unused

   try {
     // Rebuild the widget here just for capture
     final Widget qrWidgetToCaptureInternal = Material( /* ... Widget Definition ... */ );
     final Uint8List? imageBytes = await screenshotController.captureFromWidget(
       qrWidgetToCaptureInternal, // Capture the locally defined widget
       context: context, delay: const Duration(milliseconds: 100),
     );
     // ... rest of save logic ...
   } catch (e) { /* ... error handling ... */ }
}


Future<void> _showDeleteConfirmationDialog(BuildContext context, String listId, String listName) async {
   if (!context.mounted) return;
   final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); } // Return AlertDialog
   );
   if (confirm == true && context.mounted) { // Re-check mounted
      try {
         await context.read<FirestoreProvider>().deleteList(listId);
         if(context.mounted) { /* ... Success SnackBar ... */ }
      } catch (e) { if (context.mounted) { /* ... Error SnackBar ... */ } }
   }
}
// --- End Helper Functions ---


class CreatedListsScreen extends StatelessWidget {
  // Removed const constructor
  CreatedListsScreen({super.key});

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Keep _switchRole - IS used by AppBar action
  Future<void> _switchRole(BuildContext context) async { /* ... */ }

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
                 child: IconButton(icon: Icon(Icons.sync_alt, size: 28.0), onPressed: () => _switchRole(context)),
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
            // ... (loading, error, empty checks) ...
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven’t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.85),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                // Use null check pattern or default value
                final listData = doc.data() as Map<String, dynamic>? ?? {};
                final String docId = doc.id;

                // Use null check or default value
                final String qrCodeData = docId;
                final Timestamp? date = listData['date'] as Timestamp?; // Keep nullable
                final String listName = listData['listName'] ?? 'Unnamed List';

                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                // Use count variables
                int filledRegular = 0; int filledWaitlist = 0; int filledBucket = 0;
                spotsMap.forEach((key, value) {
                   if (value is Map) { // Added curly braces
                      if (key.startsWith('W')) { filledWaitlist++; }
                      else if (key.startsWith('B')) { filledBucket++; }
                      else if (int.tryParse(key) != null) { filledRegular++; }
                   }
                });
                final int totalRegular = (listData['numberOfSpots'] ?? 0) as int;
                final int totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final int totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;

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
                          onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(listName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), SizedBox(height: 4), Text(listData['address'] ?? 'No Address', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis), /* Optional QR */ ]),
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
      floatingActionButton: FadeInUp( /* ... FAB ... */ ),
    );
  }
}
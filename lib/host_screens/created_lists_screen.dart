// lib/host_screens/created_lists_screen.dart

import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';

import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:flutter/services.dart';

// Import necessary screens
import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart'; // Import Show model

class CreatedListsScreen extends StatelessWidget {
  CreatedListsScreen({super.key});

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _switchRole(BuildContext context) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('user_role');
     if (!context.mounted) return;
     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()));
  }

Future<void> _showOptionsDialog(BuildContext context, String listId,
    String listName, String qrCodeData, Timestamp date, Show show) async {
  final Color primaryColor = Theme.of(context).primaryColor;
  final Color appBarColor = Colors.blue.shade400;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  // Check if current user is guest host (not owner)
  final bool isGuestHost = currentUserId != null && 
                          show.guestHostId == currentUserId && 
                          show.userId != currentUserId;

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white.withAlpha((255 * 0.95).round()),
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
            icon: Icon(Icons.edit_outlined, color: isGuestHost ? Colors.grey : appBarColor),
            label: Text('Edit', style: TextStyle(color: isGuestHost ? Colors.grey : appBarColor)),
            onPressed: isGuestHost 
                ? null 
                : () {
                    Navigator.of(dialogContext).pop();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId)));
                  },
          ),
          TextButton.icon(
            icon: Icon(Icons.download_outlined, color: appBarColor),
            label: Text('Download QR', style: TextStyle(color: appBarColor)),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _downloadQRCode(context, qrCodeData, listName);
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.delete_outline, color: isGuestHost ? Colors.grey : Colors.red.shade700),
            label: Text('Delete List', style: TextStyle(color: isGuestHost ? Colors.grey : Colors.red.shade700)),
            onPressed: isGuestHost 
                ? null 
                : () async {
                    Navigator.of(dialogContext).pop();
                    await _showDeleteConfirmationDialog(context, listId, listName);
                  },
          ),
        ],
      );
    },
  );
}

  Future<void> _downloadQRCode(BuildContext context, String qrCodeData,
      String listName) async {
    if (!context.mounted) return;

    ScreenshotController screenshotController = ScreenshotController();
    const TextStyle titleStyle = TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold, decoration: TextDecoration.none);

    try {
      final Uint8List? imageBytes = await screenshotController.captureFromWidget(
        Material(
           color: Colors.white,
           child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(listName, textAlign: TextAlign.center, style: titleStyle),
                 const SizedBox(height: 15),
                 SizedBox(
                   width: 250, height: 250,
                   child: QrImageView(
                     data: qrCodeData, version: QrVersions.auto, size: 250.0, gapless: false,
                     errorCorrectionLevel: QrErrorCorrectLevel.M, backgroundColor: Colors.white,
                   ),
                 ),
               ],
             ),
           ),
        ),
        context: context,
        delay: const Duration(milliseconds: 200),
      );

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Failed to capture QR code widget.');
      }

      final directory = await getTemporaryDirectory();
      final safeListName = listName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final String tempFilename = 'qr_${safeListName}_${DateTime.now().millisecondsSinceEpoch}.png';
      final imagePath = '${directory.path}/$tempFilename';
      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);

      bool? success = false;
      String errorMessage = 'Failed to save to gallery.';
      try {
        success = await GallerySaver.saveImage(file.path, albumName: 'Booked Mic Lists');
        if (success == true) { errorMessage = ''; }
        else { errorMessage = 'Saving to gallery failed (plugin returned false/null).'; }
      } on PlatformException catch (e) { errorMessage = e.message ?? 'Platform error saving file.'; success = false; }
      catch (e) { errorMessage = e.toString(); success = false; }
      finally {
          try { if (await file.exists()) { await file.delete(); } }
          catch (e) { /* Error deleting temp file */ }
      }

      if (!context.mounted) return;
      if (success == true) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code saved to gallery.'))); }
      else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange)); }

    } catch (e) {
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
           );
        }
     );

     if (confirm == true) {
        if (!context.mounted) return;
        final provider = context.read<FirestoreProvider>();
        final messenger = ScaffoldMessenger.of(context);
        try {
           await provider.deleteList(listId);
           messenger.showSnackBar(SnackBar(content: Text('List "$listName" deleted.')));
        } catch (e) {
           messenger.showSnackBar(SnackBar(content: Text('Error deleting list: $e'), backgroundColor: Colors.red));
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = Colors.blue.shade600;
    final firestoreProvider = context.read<FirestoreProvider>();

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
        child: StreamBuilder<List<Show>>(
          stream: context.read<FirestoreProvider>().getShowsForUser(currentUserId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
            if (snapshot.hasError) return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('You haven\'t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            final shows = snapshot.data!;

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: shows.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.8),
itemBuilder: (context, index) {
  final show = shows[index];
  final String docId = show.id;
  
  final String qrCodeData = docId;
  final Timestamp date = Timestamp.fromDate(show.date);
  final String listName = show.showName;
  
  // Check if current user is owner or guest host
  final bool isOwner = show.userId == currentUserId;
  final bool isGuestHost = !isOwner && show.guestHostId == currentUserId;

  final spotsMap = show.spots;
  int filledRegular = 0; int filledWaitlist = 0;
  spotsMap.forEach((key, value) {
     if (value is Map) {
        if (key.startsWith('W')) { filledWaitlist++; }
        else if (int.tryParse(key) != null) { filledRegular++; }
     }
  });
  final int totalRegular = show.numberOfSpots;
  final int totalWaitlist = show.numberOfWaitlistSpots;
  final int totalBucketSpots = show.numberOfBucketSpots;

  return FadeInUp(
    delay: Duration(milliseconds: 100 * index),
    duration: const Duration(milliseconds: 400),
    child: GestureDetector(
       onLongPress: isGuestHost 
           ? () {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Guest hosts cannot delete lists'), backgroundColor: Colors.orange)
               );
             }
           : () => _showDeleteConfirmationDialog(context, docId, listName),
       child: Card(
         color: isGuestHost 
             ? Colors.orange.shade50  // Different background for guest-hosted lists
             : Colors.white.withAlpha((255 * 0.9).round()),
         elevation: 3,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         clipBehavior: Clip.antiAlias,
         child: Stack(
           children: [
             InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showOptionsDialog(context, docId, listName, qrCodeData, date, show),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ 
                        // Add guest host indicator badge
                        if (isGuestHost)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text('Guest Host', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        if (isGuestHost) SizedBox(height: 4),
                        
                        Text(listName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), 
                        SizedBox(height: 2), 
                        Text(show.address, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis), 
                        SizedBox(height: 6), 
                        Center( 
                          child: QrImageView( 
                            data: qrCodeData, 
                            version: QrVersions.auto, 
                            size: 65.0, 
                            gapless: true, 
                            backgroundColor: Colors.white, 
                            errorStateBuilder: (cxt, err) => Text("QR Error", style: TextStyle(fontSize: 10, color: Colors.red))
                          ), 
                        ), 
                      ]),
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
             // Add owner/guest host indicator in corner
             if (isGuestHost)
               Positioned(
                 top: 4,
                 right: 4,
                 child: Icon(Icons.supervised_user_circle, color: Colors.orange, size: 16),
               ),
           ],
         ),
       ),
    ),
  );
}
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_gallery_saver/flutter_image_gallery_saver.dart'; // Import the new package
// Ensure widgets is imported

// Import necessary screens
import 'list_setup_screen.dart'; // Keep this for FAB navigation
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';

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

  Future<void> _showOptionsDialog(BuildContext context, String listId, String listName, String? qrCodeData, Timestamp? date) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color appBarColor = Colors.blue.shade400;
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(listName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: Text('What would you like to do with this list?', style: TextStyle(color: Colors.black87)),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: <Widget>[
            TextButton.icon(
              icon: Icon(Icons.edit_outlined, color: appBarColor),
              label: Text('Edit', style: TextStyle(color: appBarColor)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId)));
              },
            ),
            TextButton.icon(
              icon: Icon(Icons.visibility_outlined, color: appBarColor),
              label: Text('Show', style: TextStyle(color: appBarColor)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: listId)));
              },
            ),
            if (qrCodeData != null && date != null) // Only show if QR code data and date are available
              TextButton.icon(
                icon: Icon(Icons.download_outlined, color: appBarColor),
                label: Text('Download QR code', style: TextStyle(color: appBarColor)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _downloadQRCode(context, qrCodeData, listName, date.toDate());
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _downloadQRCode(BuildContext context, String qrCodeData, String listName, DateTime date) async {
    try {
      final qrPainter = QrPainter(
        data: qrCodeData,
        version: QrVersions.auto,
        color: Colors.black,
      );

      final picData = await qrPainter.toImageData(200); // Adjust size as needed
      if (picData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error generating QR code image.')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/qr_code_${listName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(date)}.png';
      final file = File(imagePath);
      await file.writeAsBytes(picData.buffer.asUint8List());

      // Use flutter_image_gallery_saver to save
      await FlutterImageGallerySaver.saveFile(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code saved to gallery.')),
      );
    } catch (e) {
      print("Error downloading QR code: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download QR code: $e')),
      );
    }
  }

  void _handleListItemTap(BuildContext context, String listId, String listName, String? qrCodeData, Timestamp? date) async {
    await _showOptionsDialog(
      context,
      listId,
      listName,
      qrCodeData,
      date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;

    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
          (Route<dynamic> route) => false,
        );
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
            padding: const EdgeInsets.only(right: 16.0),
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
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
            if (snapshot.hasError) return Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red.shade900)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven\'t created any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));

            return GridView.builder(
              padding: EdgeInsets.all(12.0),
              itemCount: snapshot.data!.docs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 0.85),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>?;
                final String docId = doc.id;

                if (listData == null) {
                  return FadeInUp(delay: Duration(milliseconds: 100 * index), child: Card(child: Center(child: Text('Error'))));
                }

                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                int filledRegular = 0, filledWaitlist = 0, filledBucket = 0;
                spotsMap.forEach((key, value) {
                  if (value is Map) {
                    if (key.startsWith('W')) {
                      filledWaitlist++;
                    } else if (key.startsWith('B')) filledBucket++;
                    else if (int.tryParse(key) != null) filledRegular++;
                  }
                });
                final totalRegular = (listData['numberOfSpots'] ?? 0) as int;
                final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;

                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  duration: const Duration(milliseconds: 400),
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _handleListItemTap(
                        context,
                        docId,
                        listData['listName'] ?? 'Unnamed List',
                        listData['qrCodeData'],
                        listData['date'],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listData['listName'] ?? 'Unnamed List',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Add the QR Code here
                                if (listData.containsKey('qrCodeData') && listData['qrCodeData'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: QrImageView(
                                      data: listData['qrCodeData'],
                                      version: QrVersions.auto,
                                      size: 60.0, // Adjust size as needed
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (totalRegular > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Regular: $filledRegular/$totalRegular',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ),
                                if (totalWaitlist > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Waitlist: $filledWaitlist/$totalWaitlist',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ),
                                if (totalBucket > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Bucket: $filledBucket/$totalBucket',
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
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
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListSetupScreen())),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          tooltip: 'Create New List',
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}

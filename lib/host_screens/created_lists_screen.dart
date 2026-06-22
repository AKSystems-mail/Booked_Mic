// lib/host_screens/created_lists_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:rxdart/rxdart.dart';

import '../widgets/booked_mic_loading.dart';
import '../services/web_download_helper.dart';
import '../services/user_service.dart';

import 'list_setup_screen.dart';
import '../role_selection_screen.dart';
import 'show_list_screen.dart';
import 'edit_list_screen.dart';

class CreatedListsScreen extends StatefulWidget {
  const CreatedListsScreen({super.key});

  @override
  State<CreatedListsScreen> createState() => _CreatedListsScreenState();
}

class _CreatedListsScreenState extends State<CreatedListsScreen> {
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteList(BuildContext context, String listId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: const Text('Are you sure you want to permanently delete this list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('Lists').doc(listId).delete();
    }
  }

  Future<void> _downloadQrCode(String listId, String listName) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating QR code...'), duration: Duration(seconds: 1)));

      Widget qrWidget = Container(
        padding: const EdgeInsets.all(40),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              listName,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: listId,
              version: QrVersions.auto,
              size: 512.0,
            ),
            const SizedBox(height: 20),
            Text(
              'Scan to join this list on Booked Mic',
              style: TextStyle(fontSize: 18, color: Colors.grey[700], decoration: TextDecoration.none),
            ),
          ],
        ),
      );

      final imageBytes = await _screenshotController.captureFromWidget(
        qrWidget,
        delay: const Duration(milliseconds: 100),
      );

      if (kIsWeb) {
        downloadFileWeb(imageBytes, "QR_${listName.replaceAll(' ', '_')}.png");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code downloaded!')));
      } else {
        try {
           await Gal.putImageBytes(imageBytes, name: "QR_$listId");
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR saved to gallery!')));
        } catch (e) {
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving to gallery: $e')));
        }
      }
    } catch (e) {
      debugPrint("Error downloading QR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate QR code.')));
    }
  }

  Future<void> _showOptionsDialog(BuildContext context, String listId, String listName, bool isGuest) async {
     await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
           return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
              title: Center(child: Text(listName, style: const TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold, fontSize: 24))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('What would you like to do with this list?', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 30),
                  _buildOptionTile(
                    icon: Icons.visibility_outlined,
                    label: 'Show',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ShowListScreen(listId: listId)));
                    },
                  ),
                  if (!isGuest)
                    _buildOptionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditListScreen(listId: listId)));
                      },
                    ),
                  _buildOptionTile(
                    icon: Icons.file_download_outlined,
                    label: 'Download QR',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _downloadQrCode(listId, listName);
                    },
                  ),
                  if (!isGuest)
                    _buildOptionTile(
                      icon: Icons.delete_outline,
                      label: 'Delete List',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        _deleteList(context, listId);
                      },
                    ),
                ],
              ),
           );
        }
     );
  }

  Widget _buildOptionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 40.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
       return const Scaffold(body: BookedMicLoading());
    }

    final ownerStream = FirebaseFirestore.instance.collection('Lists').where('userId', isEqualTo: currentUserId).snapshots();
    final guestStream = FirebaseFirestore.instance.collection('Lists').where('guestHostUserId', isEqualTo: currentUserId).snapshots();

    return Scaffold(
      appBar: AppBar(
         centerTitle: false,
         backgroundColor: Colors.transparent, elevation: 0,
         flexibleSpace: Container(
           decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [Colors.blue.shade400, Colors.blue.shade400],
             ),
           ),
         ),
         title: const Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Booked Mic', style: TextStyle(fontSize: 14, color: Colors.white70)),
             Text('Created Lists', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
           ],
         ),
          actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue.shade800,
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.sync_alt, size: 16),
            label: const Text('Switch Role', style: TextStyle(fontSize: 12)),
            onPressed: () => _switchRole(context),
          ),
          ),
          ],
        ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: Column(
          children: [
            StreamBuilder<String?>(
              stream: UserService().getHostCodeStream(),
              builder: (context, snapshot) {
                final code = snapshot.data;
                final bool hasCode = code != null && code.isNotEmpty;
                
                if (!hasCode) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Pulse(
                      infinite: true,
                      child: const Text(
                        'GENERATING CODE...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'HOST CODE: $code',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                );
              }
            ),
            Expanded(
              child: StreamBuilder<List<QuerySnapshot>>(
                stream: Rx.combineLatest2(ownerStream, guestStream, (a, b) => [a, b]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const BookedMicLoading();
                  if (snapshot.hasError) return const Center(child: Text('Error loading lists.', style: TextStyle(color: Colors.red)));
                  
                  final List<DocumentSnapshot> allDocs = [];
                  if (snapshot.hasData) {
                     for (var qs in snapshot.data!) {
                        allDocs.addAll(qs.docs);
                     }
                  }
                  
                  allDocs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>?;
                    final bData = b.data() as Map<String, dynamic>?;
                    final aTime = aData?['createdAt'] as Timestamp?;
                    final bTime = bData?['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  if (allDocs.isEmpty) return const Center(child: Text('You haven\'t created or joined any lists yet.'));

                  return GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: allDocs.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final doc = allDocs[index];
                      final listData = doc.data() as Map<String, dynamic>? ?? {};
                      final String docId = doc.id;
                      final bool isGuest = listData['userId'] != currentUserId;

                      final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                      int filledRegular = 0;
                      spotsMap.forEach((key, value) { if (value is Map && value.isNotEmpty && int.tryParse(key) != null) filledRegular++; });
                      final totalRegular = (listData['numberOfSpots'] ?? 0) as int;

                      return FadeInUp(
                        delay: Duration(milliseconds: 100 * index),
                        child: Card(
                          color: isGuest ? const Color(0xFFFFF3E0) : Colors.white.withValues(alpha: 0.9),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isGuest ? const BorderSide(color: Colors.orange, width: 1) : BorderSide.none,
                          ),
                          child: InkWell(
                             onTap: () => _showOptionsDialog(context, docId, listData['listName'] ?? 'Unnamed List', isGuest),
                             child: Padding(
                               padding: const EdgeInsets.all(12.0),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       Expanded(child: Text(listData['listName'] ?? 'Unnamed List', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                       if (isGuest)
                                         Column(
                                           crossAxisAlignment: CrossAxisAlignment.end,
                                           children: [
                                             const Text('GUEST', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 9)),
                                             Icon(Icons.people_outline, size: 16, color: Colors.orange.shade800),
                                           ],
                                         ),
                                     ],
                                   ),
                                   Text(listData['address'] ?? 'No Venue', style: const TextStyle(color: Colors.black45, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                   const Spacer(),
                                   Center(
                                     child: SizedBox(
                                       width: 100,
                                       height: 100,
                                       child: QrImageView(
                                         data: docId,
                                         version: QrVersions.auto,
                                         size: 100.0,
                                       ),
                                     ),
                                   ),
                                   const Spacer(),
                                   Text('Regular: $filledRegular/$totalRegular', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListSetupScreen())),
        backgroundColor: Colors.blue.shade400,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

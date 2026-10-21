// lib/performer_screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';

import '../widgets/booked_mic_loading.dart';

class SignupScreen extends StatefulWidget {
  final String listId;

  const SignupScreen({super.key, required this.listId});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum SpotType { regular, waitlist, bucket }

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _performerStageName;
  String? _performerId;
  bool _isLoadingPerformer = true;
  bool _isProcessing = false;

  String? _selectedSpotKey;

  @override
  void initState() {
    super.initState();
    _fetchPerformerData();
    _checkInitialListFullness();
  }

  Future<void> _fetchPerformerData() async {
     setState(() { _isLoadingPerformer = true; });
     try {
       final user = _auth.currentUser;
       if (user != null) {
         _performerId = user.uid;
         DocumentSnapshot userDoc = await _firestore.collection('users').doc(_performerId).get();
         if (userDoc.exists && userDoc.data() != null) {
           var userData = userDoc.data() as Map<String, dynamic>;
           _performerStageName = userData['stageName'] ?? user.email ?? 'Unknown Performer';
         } else {
           _performerStageName = user.email ?? 'Unknown Performer';
         }
       }
     } catch (e) {
       debugPrint("Error fetching performer data: $e");
     } finally {
       if (mounted) setState(() { _isLoadingPerformer = false; });
     }
  }

  Future<void> _checkInitialListFullness() async {
     try {
       DocumentSnapshot listSnap = await _firestore.collection('Lists').doc(widget.listId).get();
       if (!listSnap.exists) { _showErrorAndGoBack("List not found."); return; }
     } catch (e) {
       debugPrint("Error checking list fullness: $e");
       _showErrorAndGoBack("Error loading list details.");
     }
  }

  void _showErrorAndGoBack(String message) {
     if (!mounted) return;
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
       Navigator.of(context).pop();
     });
  }

  void _selectSpot(String spotKey, bool isAvailable) {
     if (!isAvailable || _isLoadingPerformer || _performerStageName == null) return;
     setState(() { _selectedSpotKey = spotKey; });
  }

  void _cancelSelection() {
     setState(() { _selectedSpotKey = null; });
  }

  Future<void> _confirmSelection() async {
     if (_selectedSpotKey == null || _performerStageName == null || _performerId == null || _isProcessing) return;
     setState(() { _isProcessing = true; });
     final listRef = _firestore.collection('Lists').doc(widget.listId);
     try {
       await _firestore.runTransaction((transaction) async {
         DocumentSnapshot snapshot = await transaction.get(listRef);
         if (!snapshot.exists) throw Exception("List does not exist.");
         Map<String, dynamic> listData = snapshot.data() as Map<String, dynamic>;
         Map<String, dynamic> spots = Map<String, dynamic>.from(listData['spots'] ?? {});
         
          final existingSpot = spots[_selectedSpotKey!];
          // Mirror the read-side availability check: a spot is "taken" only
          // if it has a userId or name. Empty maps and isOver-only entries
          // are available. The old `isNotEmpty` check rejected isOver-only
          // spots that the read side rendered as "available".
          if (existingSpot is Map && (existingSpot['userId'] != null || existingSpot['name'] != null)) throw Exception("Spot not available");
         
         spots[_selectedSpotKey!] = {
           'name': _performerStageName!,
           'userId': _performerId!,
           'timestamp': FieldValue.serverTimestamp(),
           'isOver': false,
         };
         transaction.update(listRef, {
           'spots': spots,
           'signedUpUserIds': FieldValue.arrayUnion([_performerId!])
         });
       });
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signed up for spot $_selectedSpotKey!'), backgroundColor: Colors.green));
         setState(() { _selectedSpotKey = null; });
       }
     } catch (e) {
       debugPrint("Error confirming selection: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains("Spot not available") ? 'Sorry, that spot was just taken!' : 'Error signing up: ${e.toString()}'), backgroundColor: Colors.red));
         _cancelSelection();
       }
     } finally {
       if (mounted) setState(() { _isProcessing = false; });
     }
  }

  Future<void> _toggleBucketSignup(bool inBucket) async {
    if (_performerId == null || _performerStageName == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final bucketRef = _firestore.collection('Lists').doc(widget.listId).collection('bucketSignups').doc(_performerId);
      if (inBucket) {
        // Leave Bucket
        await bucketRef.delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from bucket.'), backgroundColor: Colors.orange));
      } else {
        // Join Bucket
        await bucketRef.set({
          'userId': _performerId,
          'stageName': _performerStageName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to bucket!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating bucket: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeSignup(String spotKey) async {
     if (_isProcessing || _performerId == null) return;
     setState(() { _isProcessing = true; });
     final listRef = _firestore.collection('Lists').doc(widget.listId);
     try {
       await _firestore.runTransaction((transaction) async {
         final docSnap = await transaction.get(listRef);
         if (!docSnap.exists) return;
         
         transaction.update(listRef, {
           'spots.$spotKey': FieldValue.delete(),
           'signedUpUserIds': FieldValue.arrayRemove([_performerId!])
         });
       });
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed from spot $spotKey'), backgroundColor: Colors.orange));
       if (_selectedSpotKey == spotKey) _cancelSelection();
     } catch (e) {
       debugPrint("Error removing signup: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing signup: $e'), backgroundColor: Colors.red));
     } finally {
       if (mounted) setState(() { _isProcessing = false; });
     }
  }

  Future<bool?> _showRemoveConfirmationDialog(String spotKey) async {
    final Color appBarColor = Colors.blue.shade400;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Confirm Removal', style: TextStyle(color: Colors.blue.shade700)),
          content: Text('Are you sure you want to remove yourself from spot $spotKey?', style: const TextStyle(color: Colors.black87)),
          actions: <Widget>[
            TextButton(child: Text('Cancel', style: TextStyle(color: appBarColor)), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: Text('Remove', style: TextStyle(color: Colors.red.shade700)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot>(
           stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
           builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                 var listData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                 return Text(listData['listName'] ?? 'Signup List');
              }
              return const Text('Signup List');
           }
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: _isLoadingPerformer
            ? const Center(child: BookedMicLoading())
            : StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const BookedMicLoading();
                  if (snapshot.hasError) return Center(child: Text('Error loading list: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
                  if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('List not found.', style: TextStyle(color: Colors.black54)));

                  var listData = snapshot.data!.data() as Map<String, dynamic>;
                  final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
                  final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                  final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
                  final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};

                  return _buildListContent(listData, spotsMap, totalSpots, totalWaitlist, totalBucket);
                },
              ),
      ),
    );
  }

  Widget _buildListContent(Map<String, dynamic> listData, Map<String, dynamic> spotsMap, int totalSpots, int totalWaitlist, int totalBucket) {
    List<Widget> listItems = [];
    int animationIndex = 0;

     Widget buildSectionHeader(String title) {
        return FadeInDown(
           duration: const Duration(milliseconds: 400),
           child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
           ),
        );
     }

    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey) {
      final spotData = spotsMap[spotKey];
      // A spot is available if: no entry exists in the map, OR it's an empty map (no userId and no name data)
      bool isAvailable = spotData == null || (spotData is Map && spotData['userId'] == null && spotData['name'] == null);
      bool isTakenByMe = false;
      bool isOver = false;
      String titleText = 'Available';
      Color titleColor = Colors.green.shade700;
      TextDecoration textDecoration = TextDecoration.none;

      if (spotData is Map && spotData.isNotEmpty) {
         isAvailable = false;
         isTakenByMe = spotData['userId'] == _performerId;
         isOver = spotData['isOver'] == true;
         titleText = isTakenByMe ? (spotData['name'] ?? 'You') : 'Taken';
         titleColor = isOver ? Colors.grey.shade400 : (isTakenByMe ? Colors.blue.shade800 : Colors.grey.shade600);
         textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none;
      }

      bool isSelectedByMe = _selectedSpotKey == spotKey;
      if (isSelectedByMe) {
         titleText = _performerStageName ?? 'Selecting...';
         titleColor = Colors.blue;
      }

      String spotLabel = type == SpotType.regular ? "${displayIndex + 1}." : "W${displayIndex + 1}.";

      Widget trailingWidget = isTakenByMe && !isOver
          ? IconButton(icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400), onPressed: () => _showRemoveConfirmationDialog(spotKey).then((val) { if (val == true) _removeSignup(spotKey); }))
          : (isSelectedByMe ? Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: _confirmSelection), IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: _cancelSelection)]) : const SizedBox(width: 40));

      return FadeInUp(
         delay: Duration(milliseconds: 50 * animationIndex++),
         child: Card(
            color: Colors.white.withValues(alpha: 0.9),
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
               leading: Text(spotLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
               title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: isTakenByMe || isSelectedByMe ? FontWeight.bold : FontWeight.normal, decoration: textDecoration)),
               trailing: trailingWidget,
               onTap: isAvailable ? () => _selectSpot(spotKey, true) : null,
            ),
         ),
      );
    }

    // Regular & Waitlist
    if (totalSpots > 0) {
       listItems.add(buildSectionHeader('Regular Spots'));
       for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString())); }
    }
    if (totalWaitlist > 0) {
       listItems.add(buildSectionHeader('Waitlist Spots'));
       for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}")); }
    }

    // Bucket System
    if (totalBucket > 0) {
       listItems.add(const Divider(height: 40, indent: 20, endIndent: 20));
       listItems.add(buildSectionHeader('Bucket Draw Pool'));
       
       listItems.add(StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('Lists').doc(widget.listId).collection('bucketSignups').snapshots(),
          builder: (context, snapshot) {
             bool inBucket = false;
             if (snapshot.hasData) {
                inBucket = snapshot.data!.docs.any((doc) => doc.id == _performerId);
             }

             return FadeInUp(
                child: Card(
                   color: inBucket ? Colors.blue.shade50 : Colors.white,
                   margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: inBucket ? Colors.blue : Colors.transparent, width: 2)),
                   child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                         children: [
                            const SizedBox(height: 10),
                            const Text("Add to Bucket List", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(inBucket ? "The host will draw names randomly during the show." : "Put your name in for a chance to perform.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                               onPressed: () => _toggleBucketSignup(inBucket),
                               style: ElevatedButton.styleFrom(backgroundColor: inBucket ? Colors.red.shade400 : Colors.blue.shade600, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
                               child: Text(inBucket ? "Remove Me from Bucket" : "Enter Bucket", style: const TextStyle(color: Colors.white)),
                            ),
                         ],
                      ),
                   ),
                ),
             );
          }
       ));
    }

    listItems.add(const SizedBox(height: 40));
    return listItems.isEmpty ? const Center(child: Text('No spots configured for this list.')) : ListView(children: listItems);
  }
}

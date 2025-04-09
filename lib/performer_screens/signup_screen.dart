// lib/pages/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

class SignupScreen extends StatefulWidget {
  final String listId;

  const SignupScreen({Key? key, required this.listId}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
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

  // --- Data Fetching and Checks ---
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
           print("Warning: User document not found in Firestore for uid: $_performerId. Using email as fallback name.");
         }
       } else {
         print("Error: Current user is null.");
         _performerStageName = 'Error';
       }
     } catch (e) {
       print("Error fetching performer data: $e");
       _performerStageName = 'Error';
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching your profile: $e')),
         );
       }
     } finally {
       if (mounted) {
         setState(() { _isLoadingPerformer = false; });
       }
     }
  }

  Future<void> _checkInitialListFullness() async {
     try {
        DocumentSnapshot listSnap = await _firestore.collection('Lists').doc(widget.listId).get();
        if (!listSnap.exists) {
           _showErrorAndGoBack("List not found.");
           return;
        }
        var listData = listSnap.data() as Map<String, dynamic>;
        final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};
        final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
        final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
        final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
        final maxSignups = totalSpots + totalWaitlist + totalBucket;
        int currentSignups = 0;
        spotsMap.forEach((key, value) { if (value is Map) currentSignups++; });
        if (currentSignups >= maxSignups) {
          _showErrorAndGoBack("Sorry, this list is full.");
        }
     } catch (e) {
        print("Error checking list fullness: $e");
        _showErrorAndGoBack("Error loading list details.");
     }
  }

  void _showErrorAndGoBack(String message) {
     if (!mounted) return;
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message), duration: Duration(seconds: 3)),
        );
        Navigator.of(context).pop();
     });
  }
  // --- End Data Fetching ---


  // --- Spot Logic ---
  void _selectSpot(String spotKey, bool isAvailable) {
     if (!isAvailable || _isLoadingPerformer || _performerStageName == null) return;
     setState(() { _selectedSpotKey = spotKey; });
  }

  void _cancelSelection() {
     setState(() { _selectedSpotKey = null; });
  }

  // --- *** CORRECTED _confirmSelection *** ---
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

         if (spots.containsKey(_selectedSpotKey!)) {
           throw Exception("Spot not available");
         } else {
           // Spot is available, claim it
           spots[_selectedSpotKey!] = {
              'name': _performerStageName!,
              'userId': _performerId!,
              // 'timestamp': FieldValue.serverTimestamp(), // <-- REMOVED THIS LINE
           };
           // Update only spots map and signedUpUserIds array
           transaction.update(listRef, {
              'spots': spots,
              'signedUpUserIds': FieldValue.arrayUnion([_performerId!])
           });
         }
       });
       // Success
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signed up for spot $_selectedSpotKey!'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
       }
     } catch (e) {
       // Handle failure
       print("Error confirming selection: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString() == "Exception: Spot not available" ? 'Sorry, that spot was just taken!' : 'Error signing up: ${e.toString()}'), backgroundColor: Colors.red));
          _cancelSelection();
        }
     } finally {
        if (mounted) setState(() { _isProcessing = false; });
     }
  }
  // --- *** END CORRECTION *** ---

  // --- End Spot Logic ---


  // --- Removal Logic ---
  Future<bool?> _showRemoveConfirmationDialog(String spotKey) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color appBarColor = Colors.blue.shade400;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Confirm Removal', style: TextStyle(color: primaryColor)),
          content: Text('Are you sure you want to remove yourself from spot $spotKey?', style: TextStyle(color: Colors.black87)),
          actions: <Widget>[
            TextButton(child: Text('Cancel', style: TextStyle(color: appBarColor)), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: Text('Remove', style: TextStyle(color: Colors.red.shade700)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
  }

  Future<void> _removeSignup(String spotKey) async {
     if (_isProcessing || _performerId == null) return;
     setState(() { _isProcessing = true; });
     final listRef = _firestore.collection('Lists').doc(widget.listId);
     try {
       await listRef.update({
         'spots.$spotKey': FieldValue.delete(),
         'signedUpUserIds': FieldValue.arrayRemove([_performerId!])
       });
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed from spot $spotKey'), backgroundColor: Colors.orange));
       if (_selectedSpotKey == spotKey) _cancelSelection();
     } catch (e) {
       print("Error removing signup: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing signup: $e'), backgroundColor: Colors.red));
     } finally {
       if (mounted) setState(() { _isProcessing = false; });
     }
  }
  // --- End Removal Logic ---


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot>(
           stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
           builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                 var listData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                 return Text(listData['listName'] ?? 'Signup List');
              }
              return Text('Signup List');
           }
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
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
        child: _isLoadingPerformer
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading list: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(child: Text('List not found.', style: TextStyle(color: Colors.black54)));
                  }

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

  // --- Helper Widget to Build List ---
  Widget _buildListContent(
      Map<String, dynamic> listData,
      Map<String, dynamic> spotsMap,
      int totalSpots,
      int totalWaitlist,
      int totalBucket)
  {
    List<Widget> listItems = [];
    int overallIndex = 0;

    Widget buildSectionHeader(String title, int delayMs) {
       return FadeInDown(
          delay: Duration(milliseconds: delayMs),
          duration: const Duration(milliseconds: 400),
          child: Padding(
             padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
             child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black.withOpacity(0.7))),
          ),
       );
    }

    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey, int animationIndex) {
      final spotData = spotsMap[spotKey];
      bool isAvailable = spotData == null;
      bool isReserved = spotData == 'RESERVED';
      bool isTaken = !isAvailable && !isReserved;
      bool isTakenByMe = false;
      String takenByName = 'Taken';
      if (isTaken) { if (spotData is Map<String, dynamic>) { if (spotData['userId'] == _performerId) { isTakenByMe = true; takenByName = spotData['name'] ?? 'You (Error reading name)'; } } else { takenByName = 'Error: Invalid Data'; } }
      bool isSelectedByMe = _selectedSpotKey == spotKey;
      String titleText; Color titleColor = Colors.black; FontWeight titleWeight = FontWeight.normal;
      if (isSelectedByMe) { titleText = _performerStageName ?? 'Selecting...'; titleColor = Colors.blue; titleWeight = FontWeight.bold; }
      else if (isTakenByMe) { titleText = takenByName; titleWeight = FontWeight.bold; titleColor = Colors.black87; } // Ensure taken by me is visible
      else if (isTaken && !isTakenByMe) { titleText = 'Taken'; titleColor = Colors.grey.shade600; } // Slightly darker grey
      else if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade700; } // Slightly darker orange
      else if (type == SpotType.bucket && isAvailable) { titleText = 'Bucket Spot'; titleColor = Colors.green.shade800; } // Slightly darker green
      else if (isAvailable) { titleText = 'Available'; titleColor = Colors.green.shade800; } // Slightly darker green
      else { titleText = 'Unknown State'; titleColor = Colors.red.shade900; }
      String spotLabel; switch (type) { case SpotType.regular: spotLabel = "${displayIndex + 1}."; break; case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break; case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break; }

      Widget trailingWidget = SizedBox(width: 60);
      if (isSelectedByMe) {
         trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: Icon(Icons.check_circle, color: Colors.green), onPressed: _isProcessing ? null : _confirmSelection, tooltip: 'Confirm Spot'), IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: _isProcessing ? null : _cancelSelection, tooltip: 'Cancel Selection'), ]);
      }

      Widget listTileContent = Card(
         color: Colors.white.withOpacity(0.9),
         elevation: 3,
         margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         child: ListTile(
           leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
           title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight)),
           trailing: trailingWidget,
           onTap: (isAvailable && !_isProcessing) ? () => _selectSpot(spotKey, isAvailable) : null,
           tileColor: isSelectedByMe ? Colors.blue.shade50.withOpacity(0.8) : null,
         ),
      );

      Widget finalTile;
      if (isTakenByMe) {
         finalTile = Dismissible(
            key: ValueKey(spotKey),
            direction: DismissDirection.endToStart,
            background: Container( decoration: BoxDecoration( color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(10) ), margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), padding: EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.centerRight, child: Icon(Icons.delete_sweep, color: Colors.white) ),
            confirmDismiss: (direction) async => await _showRemoveConfirmationDialog(spotKey),
            onDismissed: (direction) { _removeSignup(spotKey); },
            child: listTileContent,
         );
      } else {
         finalTile = listTileContent;
      }

      return FadeInUp(
         delay: Duration(milliseconds: 50 * animationIndex),
         duration: const Duration(milliseconds: 300),
         child: finalTile,
      );
    }

    // --- Building the list sections ---
    if (totalSpots > 0) { listItems.add(buildSectionHeader('Regular Spots', overallIndex * 50 + 300)); overallIndex++; for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString(), overallIndex)); overallIndex++; } if (totalWaitlist > 0 || totalBucket > 0) listItems.add(Divider(indent: 16, endIndent: 16, color: Colors.white.withOpacity(0.5))); }
    if (totalWaitlist > 0) { listItems.add(buildSectionHeader('Waitlist Spots', overallIndex * 50 + 300)); overallIndex++; for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}", overallIndex)); overallIndex++; } if (totalBucket > 0) listItems.add(Divider(indent: 16, endIndent: 16, color: Colors.white.withOpacity(0.5))); }
    if (totalBucket > 0) { listItems.add(buildSectionHeader('Bucket Spots', overallIndex * 50 + 300)); overallIndex++; for (int i = 0; i < totalBucket; i++) { listItems.add(buildSpotTile(i, SpotType.bucket, "B${i + 1}", overallIndex)); overallIndex++; } }
    // --- End list section building ---

    if (listItems.isEmpty) {
       return Center(child: Text("This list currently has no spots defined.", style: TextStyle(color: Colors.black54)));
    }

    listItems.add(SizedBox(height: 20)); // Padding at bottom
    return ListView(children: listItems);
  }
}
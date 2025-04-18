// lib/performer_screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

import 'package:provider/provider.dart'; // Import Provider
import 'package:myapp/providers/firestore_provider.dart'; // Import Provider
import 'package:myapp/models/show.dart'; // Import Show model

class SignupScreen extends StatefulWidget {
  final String listId;

  const SignupScreen({super.key, required this.listId});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum SpotType { regular, waitlist, bucket }

class _SignupScreenState extends State<SignupScreen> {
  // Use late final for instances that don't change
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final String? _performerId; // Can be final after initState

  String? _performerStageName;
  bool _isLoadingPerformer = true;
  bool _isProcessing = false; // For regular spot signup/removal
  bool _isBucketProcessing = false; // For bucket join/leave

  String? _selectedSpotKey;

  // --- State for Bucket ---
  bool _isUserAlreadyInBucket = false;
  bool _checkingBucketStatus = true; // Loading state for bucket check
  // --- End Bucket State ---

  @override
  void initState() {
    super.initState();
    // Initialize final fields
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _performerId = _auth.currentUser?.uid;

    _fetchPerformerData();
    // Removed _checkInitialListFullness - handled by StreamBuilder now
    if (_performerId != null) {
      _checkBucketStatus();
    }
  }

  // --- Data Fetching and Checks ---
  Future<void> _fetchPerformerData() async {
     setState(() { _isLoadingPerformer = true; });
     try {
       // Use final _auth and _performerId
       final user = _auth.currentUser; // Re-check just in case
       if (user != null && _performerId != null) {
         DocumentSnapshot userDoc = await _firestore.collection('users').doc(_performerId).get();
         if (mounted && userDoc.exists && userDoc.data() != null) { // Check mounted
           var userData = userDoc.data() as Map<String, dynamic>;
           _performerStageName = userData['stageName'] ?? user.email ?? 'Unknown Performer';
         } else if (mounted) {
           _performerStageName = user.email ?? 'Unknown Performer';
           // print("Warning: User document not found..."); // Commented out
         }
       } else if (mounted) {
         // print("Error: Current user is null."); // Commented out
         _performerStageName = 'Error';
       }
     } catch (e) {
       // print("Error fetching performer data: $e"); // Commented out
       if (mounted) _performerStageName = 'Error'; // Avoid setState if not mounted
       // Optionally show SnackBar if mounted
       // if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching profile: $e')));
     } finally {
       if (mounted) setState(() { _isLoadingPerformer = false; });
     }
  }


  // --- End Data Fetching ---

 // --- Check if user is in bucket ---
  Future<void> _checkBucketStatus() async {
     if (_performerId == null || !mounted) return;
     setState(() { _checkingBucketStatus = true; });
     try {
        final provider = context.read<FirestoreProvider>();
        final bool isInBucket = await provider.isUserInBucket(widget.listId, _performerId!);
        if (mounted) { // Check mounted after await
           setState(() { _isUserAlreadyInBucket = isInBucket; });
        }
     } catch (e) {
        // print("Error checking bucket status: $e"); // Commented out
        if (mounted) setState(() { _isUserAlreadyInBucket = false; }); // Assume not in bucket on error
     } finally {
        if (mounted) setState(() { _checkingBucketStatus = false; });
     }
  }
  // --- End Check ---


  // --- Spot Logic (Select/Cancel/Confirm for Regular/Waitlist) ---
  void _selectSpot(String spotKey, bool isAvailable) {
     if (!isAvailable || _isLoadingPerformer || _performerStageName == null) return;
     setState(() { _selectedSpotKey = spotKey; });
  }

  void _cancelSelection() {
     setState(() { _selectedSpotKey = null; });
  }

  Future<void> _confirmSelection() async {
     if (_selectedSpotKey == null || _performerStageName == null || _performerId == null || _isProcessing || !mounted) return;
     setState(() { _isProcessing = true; });
     final firestoreProvider = context.read<FirestoreProvider>();
     final listRef = _firestore.collection('Lists').doc(widget.listId);

     try {
       // Check bucket status before transaction
       final bool isInBucket = await firestoreProvider.isUserInBucket(widget.listId, _performerId!);
       if (isInBucket) {
          throw Exception("You are already in the bucket draw.");
       }

       await _firestore.runTransaction((transaction) async {
         DocumentSnapshot snapshot = await transaction.get(listRef);
         if (!snapshot.exists) throw Exception("List does not exist.");
         Map<String, dynamic> listData = snapshot.data() as Map<String, dynamic>? ?? {};
         Map<String, dynamic> spots = Map<String, dynamic>.from(listData['spots'] ?? {});
         List<String> signedUpIds = List<String>.from(listData['signedUpUserIds'] ?? []);

         if (spots.containsKey(_selectedSpotKey!)) throw Exception("Spot not available");
         // Check main list signup status again inside transaction for safety
         if (signedUpIds.contains(_performerId!)) {
             throw Exception("You are already signed up for a spot on this list.");
         }

         spots[_selectedSpotKey!] = { 'name': _performerStageName!, 'userId': _performerId! };
         transaction.update(listRef, { 'spots': spots, 'signedUpUserIds': FieldValue.arrayUnion([_performerId!]) });
       });

       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signed up for spot $_selectedSpotKey!'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
       }
     } catch (e) {
       // print("Error confirming selection: $e"); // Commented out
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red)); // Show cleaner message
         _cancelSelection();
       }
     } finally { if (mounted) setState(() { _isProcessing = false; }); }
  }


  // --- *** END CORRECTION *** ---
  // --- Bucket Join/Leave Logic ---
  Future<void> _toggleBucketSignup() async {
     if (_performerId == null || _performerStageName == null || _isBucketProcessing || _checkingBucketStatus || !mounted) return;

     setState(() { _isBucketProcessing = true; });
     final firestoreProvider = context.read<FirestoreProvider>();
     final listRef = _firestore.collection('Lists').doc(widget.listId);

     try {
        final listSnap = await listRef.get();
        final listData = listSnap.data() ?? {};
        final signedUpIds = List<String>.from(listData['signedUpUserIds'] ?? []);
        if (signedUpIds.contains(_performerId!)) {
           throw Exception("Cannot join bucket draw; you are already signed up for a main/waitlist spot.");
        }

        // Use the current state checked in initState/updated after action
        if (_isUserAlreadyInBucket) {
           await firestoreProvider.removeUserFromBucket(widget.listId, _performerId!);
           if (mounted) {
              setState(() { _isUserAlreadyInBucket = false; }); // Update local state
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed from bucket draw.'), backgroundColor: Colors.orange));
           }
        } else {
           await firestoreProvider.addUserToBucket(widget.listId, _performerId!, _performerStageName!);
           if (mounted) {
              setState(() { _isUserAlreadyInBucket = true; }); // Update local state
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined bucket draw!'), backgroundColor: Colors.green));
           }
        }
     } catch (e) {
        // print("Error toggling bucket signup: $e"); // Commented out
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: Colors.red));
        }
     } finally {
        if (mounted) setState(() { _isBucketProcessing = false; });
     }
  }
  // --- End Spot Logic ---


  // --- Removal Logic ---
  Future<bool?> _showRemoveConfirmationDialog(String spotKey) async {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color appBarColor = Colors.blue.shade400;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white.withAlpha(0.95 as int),
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
     if (_isProcessing || _performerId == null || !mounted) return;
     setState(() { _isProcessing = true; });
     final firestoreProvider = context.read<FirestoreProvider>();
     try {
       await firestoreProvider.removePerformerFromSpot(widget.listId, spotKey);
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed from spot $spotKey'), backgroundColor: Colors.orange)); }
       if (_selectedSpotKey == spotKey) _cancelSelection();
     } catch (e) { /* ... Error handling ... */ }
     finally { if (mounted) setState(() { _isProcessing = false; }); }
  }
  // --- End Removal Logic ---


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final firestoreProvider = context.watch<FirestoreProvider>();
    final Color appBarColor = Colors.blue.shade400;
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: StreamBuilder<Show>(
           stream: firestoreProvider.getShow(widget.listId),
            builder: (context, snapshot) {
              if (snapshot.hasData) return Text(snapshot.data!.showName);
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
            : StreamBuilder<Show>(
                stream: firestoreProvider.getShow(widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: primaryColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading list: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return Center(child: Text('List not found.', style: TextStyle(color: Colors.black54)));
              }

              final showData = snapshot.data!; // Use Show object
                  // Check if user is already signed up for a main/waitlist spot
                  final bool isSignedUpOnMainList = _performerId != null && showData.signedUpUserIds.contains(_performerId);

                  // Ensure builder returns a Widget
                  return _buildListContent(
                     showData, // Pass Show object
                     isSignedUpOnMainList
                  );
                },
              ),
      ),
    );
  }

  // --- Helper Widget to Build List ---
  Widget _buildListContent(Show showData, bool isSignedUpOnMainList) {
    List<Widget> listItems = [];
    int overallIndex = 0;

    // Access data from showData
    final spotsMap = showData.spots;
    final totalSpots = showData.numberOfSpots;
    final totalWaitlist = showData.numberOfWaitlistSpots;
    final totalBucket = showData.numberOfBucketSpots;

    Widget buildSectionHeader(String title, double delayMsDouble) {
       return FadeInDown(
          // Ensure integer value for milliseconds
          delay: Duration(milliseconds: delayMsDouble.round()), // Use .round() or .toInt()
          duration: const Duration(milliseconds: 400),
          child: Padding(
             padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
             child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black.withAlpha((255 * 0.7).round()))), // Use withAlpha
          ),
       );
    }

    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey, int animationIndex) {
      final spotData = spotsMap[spotKey];
      bool isAvailable = spotData == null;
      bool isReserved = spotData is String && spotData == 'RESERVED'; // Corrected check
      bool isTaken = !isAvailable && !isReserved;
      bool isTakenByMe = false;
      String takenByName = 'Taken';
      if (isTaken) { if (spotData is Map<String, dynamic>) { if (spotData['userId'] == _performerId) { isTakenByMe = true; takenByName = spotData['name'] ?? 'You (Error reading name)'; } } else { takenByName = 'Error: Invalid Data'; } }
      bool isSelectedByMe = _selectedSpotKey == spotKey;
      String titleText; Color titleColor = Colors.black; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none; // Initialize
      if (isSelectedByMe) { titleText = _performerStageName ?? 'Selecting...'; titleColor = Colors.blue; titleWeight = FontWeight.bold; }
      else if (isTakenByMe) { titleText = takenByName; titleWeight = FontWeight.bold; titleColor = Colors.black87; }
      else if (isTaken && !isTakenByMe) { titleText = 'Taken'; titleColor = Colors.grey.shade600; }
      else if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade700; }
      else if (isAvailable) { titleText = 'Available'; titleColor = Colors.green.shade800; }
      else { titleText = 'Unknown State'; titleColor = Colors.red.shade900; }
      String spotLabel; switch (type) { case SpotType.regular: spotLabel = "${displayIndex + 1}."; break; case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break; case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break; }

      Widget trailingWidget = SizedBox(width: 60);
      if (isSelectedByMe) {
        trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: Icon(Icons.check_circle, color: Colors.green), onPressed: _isProcessing ? null : _confirmSelection, tooltip: 'Confirm Spot'), IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: _isProcessing ? null : _cancelSelection, tooltip: 'Cancel Selection'), ]);
      }

      Widget listTileContent = Card( color: Colors.white.withAlpha((255 * 0.9).round()), elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         child: ListTile(
           leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
           title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)), // Use initialized vars
           trailing: trailingWidget,
           onTap: (isAvailable && !_isProcessing) ? () => _selectSpot(spotKey, isAvailable) : null,
           tileColor: isSelectedByMe ? Colors.blue.shade50.withAlpha((200).round()) : null, // Use withAlpha
         ),
      );

      Widget finalTile;
      if (isTakenByMe) {
         finalTile = Dismissible( key: ValueKey(spotKey), direction: DismissDirection.endToStart, background: Container( /* ... */ ),
            confirmDismiss: (direction) async => await _showRemoveConfirmationDialog(spotKey),
            onDismissed: (direction) { _removeSignup(spotKey); },
            child: listTileContent,
         );
      } else {
         finalTile = listTileContent;
      }

      return FadeInUp( delay: Duration(milliseconds: 50 * animationIndex), duration: const Duration(milliseconds: 300), child: finalTile );
    }

    // --- Building the list sections (Regular, Waitlist ONLY) ---
    if (totalSpots > 0) {
       listItems.add(buildSectionHeader('Regular Spots', overallIndex * 50 + 300)); overallIndex++;
       for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString(), overallIndex)); overallIndex++; }
       if (totalWaitlist > 0) listItems.add(Divider(indent: 16, endIndent: 16, color: Colors.white.withAlpha((255 * 0.5).round())));
    }
    if (totalWaitlist > 0) {
      listItems.add(buildSectionHeader('Waitlist Spots', overallIndex * 50 + 300)); overallIndex++;
      for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}", overallIndex)); overallIndex++; }
    }
    // --- REMOVED Bucket Spot Loop ---

      if (totalBucket > 0) {
       listItems.add(Divider(indent: 16, endIndent: 16, color: Colors.white.withAlpha((255 * 0.5).round())));
       listItems.add(buildSectionHeader('Bucket Draw', overallIndex * 50 + 300));
       overallIndex++;
       listItems.add(
          FadeInUp(
             delay: Duration(milliseconds: 50 * overallIndex),
             duration: const Duration(milliseconds: 400),
             child: Card(
                color: Colors.white.withAlpha((255 * 0.9).round()),
                elevation: 3,
                margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                      children: [
                         // StreamBuilder for the count
                         StreamBuilder<int>(
                            stream: context.read<FirestoreProvider>().getBucketSignupCountStream(widget.listId),
                            builder: (context, countSnapshot) {
                               int currentBucketSignups = countSnapshot.data ?? 0;
                               if (countSnapshot.connectionState == ConnectionState.waiting && !countSnapshot.hasData) {
                                  return Text("Loading bucket count...", style: TextStyle(color: Colors.grey.shade600));
                               }
                               return Text(
                                  "Signups: $currentBucketSignups / $totalBucket Spots Available",
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                               );
                            }
                         ),
                         SizedBox(height: 15),
                         // Join/Leave Button
                         _checkingBucketStatus // Show loader while checking initial status
                            ? CircularProgressIndicator(strokeWidth: 2)
                            : ElevatedButton.icon(
                                icon: Icon(_isUserAlreadyInBucket ? Icons.person_remove_alt_1 : Icons.person_add_alt_1, color: Colors.white),
                                label: Text(_isUserAlreadyInBucket ? 'Pull Name From Bucket' : 'Name In Bucket'),
                                style: ElevatedButton.styleFrom(
                                   backgroundColor: _isUserAlreadyInBucket ? Colors.orange.shade700 : Theme.of(context).primaryColor,
                                   foregroundColor: Colors.white,
                                   padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                // Disable button if processing, or if already on main list
                                onPressed: (_isBucketProcessing || isSignedUpOnMainList)
                                    ? null
                                    : _toggleBucketSignup,
                             ),
                         if (isSignedUpOnMainList) // Show message if on main list
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                 "You are already signed up for a spot.",
                                 style: TextStyle(color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                              ),
                            ),
                      ],
                   ),
                ),
             ),
          )
       );
    }

    if (listItems.isEmpty) {
      return Center(child: Text("This list currently has no spots defined.", style: TextStyle(color: Colors.black54)));
    }

    listItems.add(SizedBox(height: 20)); // Padding at bottom
    return ListView(children: listItems);
  }
}
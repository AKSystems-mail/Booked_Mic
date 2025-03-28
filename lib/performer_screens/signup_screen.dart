// lib/pages/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Use stageName now
  String? _performerStageName;
  String? _performerId;
  bool _isLoadingPerformer = true;
  bool _isProcessing = false; // To prevent double taps on confirm/cancel

  String? _selectedSpotKey; // Firestore map key (e.g., "3", "W1", "B2")

  @override
  void initState() {
    super.initState();
    _fetchPerformerData();
    _checkInitialListFullness(); // Check fullness when screen loads
  }

  Future<void> _fetchPerformerData() async {
    setState(() { _isLoadingPerformer = true; });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _performerId = user.uid;
        // Fetch the specific 'stageName' field from 'users' collection
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_performerId).get();
        if (userDoc.exists && userDoc.data() != null) {
           var userData = userDoc.data() as Map<String, dynamic>;
           // Use 'stageName' field, provide fallback if missing
           _performerStageName = userData['stageName'] ?? user.email ?? 'Unknown Performer';
        } else {
          _performerStageName = user.email ?? 'Unknown Performer'; // Fallback if user doc doesn't exist
          print("Warning: User document not found in Firestore for uid: $_performerId. Using email as fallback name.");
        }
      } else {
         print("Error: Current user is null.");
         _performerStageName = 'Error'; // Indicate error state
      }
    } catch (e) {
      print("Error fetching performer data: $e");
      _performerStageName = 'Error'; // Indicate error state
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
        spotsMap.forEach((key, value) {
          if (value is Map) { // Count only actual signups (Maps), not 'RESERVED' strings
            currentSignups++;
          }
        });

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
     // Use addPostFrameCallback to ensure build context is valid after potential async gap
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // Double check after frame callback
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message), duration: Duration(seconds: 3)),
        );
        // Navigate back after showing the message
        Navigator.of(context).pop();
     });
  }


  // --- Logic for Spot Selection and Confirmation ---

  void _selectSpot(String spotKey, bool isAvailable) {
    // Use _performerStageName for check
    if (!isAvailable || _isLoadingPerformer || _performerStageName == null) return;
    setState(() { _selectedSpotKey = spotKey; });
  }

  void _cancelSelection() {
    setState(() { _selectedSpotKey = null; });
  }

  Future<void> _confirmSelection() async {
    // Use _performerStageName
    if (_selectedSpotKey == null || _performerStageName == null || _performerId == null || _isProcessing) return;

    setState(() { _isProcessing = true; });

    final listRef = _firestore.collection('Lists').doc(widget.listId);

    try {
      // Use a transaction to prevent race conditions
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(listRef);
        if (!snapshot.exists) throw Exception("List does not exist.");

        Map<String, dynamic> listData = snapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> spots = Map<String, dynamic>.from(listData['spots'] ?? {});

        // Check if the selected spot is still available
        if (spots.containsKey(_selectedSpotKey!)) {
          throw Exception("Spot not available");
        } else {
          // Spot is available, claim it
          spots[_selectedSpotKey!] = {
             'name': _performerStageName!, // Use stage name
             'userId': _performerId!,
             'timestamp': FieldValue.serverTimestamp(),
          };
          // Also update the signedUpUserIds array
          transaction.update(listRef, {
             'spots': spots,
             'signedUpUserIds': FieldValue.arrayUnion([_performerId!]) // Add user ID to array
          });
        }
      });

      // Success
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Signed up for spot $_selectedSpotKey!'), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop(); // Go back after successful signup
      }

    } catch (e) {
      // Handle failure (spot taken or other error)
      print("Error confirming selection: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString() == "Exception: Spot not available" ? 'Sorry, that spot was just taken!' : 'Error signing up: ${e.toString()}'), backgroundColor: Colors.red),
         );
         _cancelSelection(); // Clear selection on error
       }
    } finally {
       if (mounted) setState(() { _isProcessing = false; });
    }
  }

  // --- Logic for Removing Signup ---

  Future<bool?> _showRemoveConfirmationDialog(String spotKey) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Removal'),
          content: Text('Are you sure you want to remove yourself from spot $spotKey?'),
          actions: <Widget>[
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: Text('Remove', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );
  }

  Future<void> _removeSignup(String spotKey) async {
     // Added null check for performerId
     if (_isProcessing || _performerId == null) return;
     setState(() { _isProcessing = true; });

     final listRef = _firestore.collection('Lists').doc(widget.listId);

     try {
        // Remove spot key AND remove user from signedUpUserIds array
        await listRef.update({
           'spots.$spotKey': FieldValue.delete(),
           'signedUpUserIds': FieldValue.arrayRemove([_performerId!]) // Remove user ID from array
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Removed from spot $spotKey'), backgroundColor: Colors.orange),
           );
        }
        if (_selectedSpotKey == spotKey) _cancelSelection();
     } catch (e) {
        print("Error removing signup: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error removing signup: $e'), backgroundColor: Colors.red),
           );
        }
     } finally {
        if (mounted) setState(() { _isProcessing = false; });
     }
  }


  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
           stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
           builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                 var listData = snapshot.data!.data() as Map<String, dynamic>;
                 return Text(listData['listName'] ?? 'Signup List');
              }
              return Text('Signup List');
           }
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingPerformer
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading list: ${snapshot.error}'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: Text('List not found.'));
                }

                var listData = snapshot.data!.data() as Map<String, dynamic>;
                final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
                final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
                final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};

                return _buildListContent(listData, spotsMap, totalSpots, totalWaitlist, totalBucket);
              },
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

    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey) {
      final spotData = spotsMap[spotKey];
      bool isAvailable = spotData == null;
      bool isReserved = spotData == 'RESERVED';
      bool isTaken = !isAvailable && !isReserved;
      bool isTakenByMe = false;
      String takenByName = 'Taken'; // Default text if taken by other

      if (isTaken) {
        // Check if spotData is a Map before accessing fields
        if (spotData is Map<String, dynamic>) {
           if (spotData['userId'] == _performerId) {
             isTakenByMe = true;
             // Display the name stored in the spot data (which should be the stage name)
             takenByName = spotData['name'] ?? 'You (Error reading name)';
           }
           // If not taken by me, takenByName remains 'Taken'
        } else {
           // Handle unexpected data type in spotData if necessary
           print("Warning: Unexpected data type found for spot $spotKey: $spotData");
           takenByName = 'Error: Invalid Data';
        }
      }

      bool isSelectedByMe = _selectedSpotKey == spotKey;

      String titleText;
      Color titleColor = Colors.black;
      FontWeight titleWeight = FontWeight.normal;

      if (isSelectedByMe) {
        titleText = _performerStageName ?? 'Selecting...'; // Use stage name
        titleColor = Colors.blue;
        titleWeight = FontWeight.bold;
      } else if (isTakenByMe) {
         titleText = takenByName; // Already holds stage name from spot data
         titleWeight = FontWeight.bold;
      } else if (isTaken && !isTakenByMe) {
        titleText = 'Taken';
        titleColor = Colors.grey;
      } else if (isReserved) {
        titleText = 'Reserved';
        titleColor = Colors.orange;
      } else if (type == SpotType.bucket && isAvailable) {
         titleText = 'Bucket Spot';
         titleColor = Colors.green.shade700;
      }
      else if (isAvailable) { // Available regular/waitlist
        titleText = 'Available';
        titleColor = Colors.green.shade700;
      } else {
         titleText = 'Unknown State'; titleColor = Colors.red;
      }

      String spotLabel;
       switch (type) {
         case SpotType.regular: spotLabel = "${displayIndex + 1}."; break;
         case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break;
         case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break;
       }

      Widget trailingWidget = SizedBox(width: 60); // Placeholder for alignment
      if (isSelectedByMe) {
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.check_circle, color: Colors.green), onPressed: _isProcessing ? null : _confirmSelection, tooltip: 'Confirm Spot'),
            IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: _isProcessing ? null : _cancelSelection, tooltip: 'Cancel Selection'),
          ],
        );
      }

      ListTile listTile = ListTile(
        leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
        title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight)),
        trailing: trailingWidget,
        onTap: (isAvailable && !_isProcessing) ? () => _selectSpot(spotKey, isAvailable) : null,
        tileColor: isSelectedByMe ? Colors.blue.shade50 : null,
      );

      if (isTakenByMe) {
         return Dismissible(
            key: ValueKey(spotKey),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, padding: EdgeInsets.symmetric(horizontal: 20), alignment: Alignment.centerRight, child: Icon(Icons.delete_sweep, color: Colors.white)),
            confirmDismiss: (direction) async => await _showRemoveConfirmationDialog(spotKey),
            onDismissed: (direction) { _removeSignup(spotKey); },
            child: listTile,
         );
      } else {
         return listTile;
      }
    }

    // --- Building the list sections (Regular, Waitlist, Bucket) ---
    if (totalSpots > 0) {
       listItems.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text('Regular Spots', style: Theme.of(context).textTheme.titleMedium)));
       for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString())); }
       listItems.add(Divider());
    }
    if (totalWaitlist > 0) {
      listItems.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text('Waitlist Spots', style: Theme.of(context).textTheme.titleMedium)));
      for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}")); }
      listItems.add(Divider());
    }
    if (totalBucket > 0) {
      listItems.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text('Bucket Spots', style: Theme.of(context).textTheme.titleMedium)));
      for (int i = 0; i < totalBucket; i++) { listItems.add(buildSpotTile(i, SpotType.bucket, "B${i + 1}")); }
      listItems.add(Divider());
    }
    // --- End list section building ---

    // Add message if list has no spots defined
    if (listItems.isEmpty) {
       return Center(child: Text("This list currently has no spots defined."));
    }

    return ListView(children: listItems);
  }
}
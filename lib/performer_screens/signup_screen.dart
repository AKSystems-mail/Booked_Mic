// lib/pages/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed unused import: import 'performer_list_screen.dart';

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

  String? _performerName;
  String? _performerId;
  bool _isLoadingPerformer = true;
  bool _isProcessing = false; // To prevent double taps on confirm/cancel

  // State for tentative selection
  // Removed unused field: int _selectedSpotIndex = -1;
  // Removed unused field: SpotType? _selectedSpotType;
  String? _selectedSpotKey; // Firestore map key (e.g., "3", "W1", "B2") - THIS IS USED

  @override
  void initState() {
    super.initState();
    _fetchPerformerData();
    _checkInitialListFullness(); // Check fullness when screen loads
  }

  Future<void> _fetchPerformerData() async {
    setState(() {
      _isLoadingPerformer = true;
    });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _performerId = user.uid;
        // --- Replace with your actual logic to get performer name ---
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_performerId).get();
        if (userDoc.exists && userDoc.data() != null) {
           var userData = userDoc.data() as Map<String, dynamic>;
           _performerName = userData['displayName'] ?? userData['performerName'] ?? user.email ?? 'Unknown Performer';
        } else {
          _performerName = user.email ?? 'Unknown Performer'; // Fallback
        }
        // --- End Replace ---
      }
    } catch (e) {
      print("Error fetching performer data: $e");
      _performerName = 'Error'; // Indicate error
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching your profile: $e')),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPerformer = false;
        });
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
          // Count only actual signups (value is a Map), not reserved spots (value is 'RESERVED')
          if (value is Map) {
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
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(message), duration: Duration(seconds: 3)),
        );
        Navigator.of(context).pop();
     });
  }

  void _selectSpot(String spotKey, bool isAvailable) { // Removed unused index and type parameters
    if (!isAvailable || _isLoadingPerformer || _performerName == null) return;

    setState(() {
      // Removed unused assignments: _selectedSpotIndex = index;
      // Removed unused assignments: _selectedSpotType = type;
      _selectedSpotKey = spotKey; // Only need to track the key
    });
  }

  void _cancelSelection() {
    setState(() {
      // Removed unused assignments: _selectedSpotIndex = -1;
      // Removed unused assignments: _selectedSpotType = null;
      _selectedSpotKey = null;
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedSpotKey == null || _performerName == null || _performerId == null || _isProcessing) return;

    setState(() { _isProcessing = true; });

    final listRef = _firestore.collection('Lists').doc(widget.listId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(listRef);

        if (!snapshot.exists) {
          throw Exception("List does not exist.");
        }

        Map<String, dynamic> listData = snapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> spots = Map<String, dynamic>.from(listData['spots'] ?? {});

        if (spots.containsKey(_selectedSpotKey!)) {
          throw Exception("Spot not available");
        } else {
          spots[_selectedSpotKey!] = {
             'name': _performerName!,
             'userId': _performerId!,
             'timestamp': FieldValue.serverTimestamp(),
          };
          transaction.update(listRef, {'spots': spots});
        }
      });

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Signed up for spot $_selectedSpotKey!'), backgroundColor: Colors.green),
         );
         Navigator.of(context).pop();
      }

    } catch (e) {
      print("Error confirming selection: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.toString() == "Exception: Spot not available" ? 'Sorry, that spot was just taken!' : 'Error signing up: ${e.toString()}'), backgroundColor: Colors.red),
         );
         _cancelSelection();
       }
    } finally {
       if (mounted) {
          setState(() { _isProcessing = false; });
       }
    }
  }

  Future<bool?> _showRemoveConfirmationDialog(String spotKey) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Removal'),
          content: Text('Are you sure you want to remove yourself from spot $spotKey?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Remove', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeSignup(String spotKey) async {
     if (_isProcessing) return;
     setState(() { _isProcessing = true; });

     final listRef = _firestore.collection('Lists').doc(widget.listId);

     try {
        await listRef.update({'spots.$spotKey': FieldValue.delete()});
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Removed from spot $spotKey'), backgroundColor: Colors.orange),
           );
        }
        if (_selectedSpotKey == spotKey) {
           _cancelSelection();
        }
     } catch (e) {
        print("Error removing signup: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error removing signup: $e'), backgroundColor: Colors.red),
           );
        }
     } finally {
        if (mounted) {
           setState(() { _isProcessing = false; });
        }
     }
  }

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
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
                // Removed unused local variable: final listName = listData['listName'] ?? 'Unnamed List';
                final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
                final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
                final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};

                return _buildListContent(listData, spotsMap, totalSpots, totalWaitlist, totalBucket);
              },
            ),
    );
  }

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

      // If it's not available and not reserved, it must be taken (a Map).
      // We can safely cast or access fields within this assumption.
      bool isTaken = !isAvailable && !isReserved;
      bool isTakenByMe = false;
      String takenByName = 'Taken'; // Default text if taken by other

      if (isTaken) {
        // Assuming spotData is a Map here based on the logic above
        final spotInfo = spotData as Map<String, dynamic>;
        if (spotInfo['userId'] == _performerId) {
          isTakenByMe = true;
          takenByName = spotInfo['name'] ?? 'You (Error reading name)';
        }
        // If not taken by me, takenByName remains 'Taken'
      }

      bool isSelectedByMe = _selectedSpotKey == spotKey;

      String titleText;
      Color titleColor = Colors.black;
      FontWeight titleWeight = FontWeight.normal;

      if (isSelectedByMe) {
        titleText = _performerName ?? 'Selecting...';
        titleColor = Colors.blue;
        titleWeight = FontWeight.bold;
      } else if (isTakenByMe) {
         titleText = takenByName; // Use the name fetched earlier
         titleWeight = FontWeight.bold;
      } else if (isTaken && !isTakenByMe) { // Explicitly check if taken by other
        titleText = 'Taken';
        titleColor = Colors.grey;
      } else if (isReserved) {
        titleText = 'Reserved';
        titleColor = Colors.orange;
      } else if (type == SpotType.bucket && isAvailable) { // Check isAvailable here
         titleText = 'Bucket Spot';
         titleColor = Colors.green.shade700;
      }
      else if (isAvailable) { // Check isAvailable for regular/waitlist
        titleText = 'Available';
        titleColor = Colors.green.shade700;
      } else {
         // Fallback, should ideally not be reached with current logic
         titleText = 'Unknown State';
         titleColor = Colors.red;
      }


      String spotLabel;
       switch (type) {
         case SpotType.regular:
           spotLabel = "${displayIndex + 1}.";
           break;
         case SpotType.waitlist:
           spotLabel = "W${displayIndex + 1}.";
           break;
         case SpotType.bucket:
           spotLabel = "B${displayIndex + 1}.";
           break;
       }

      Widget trailingWidget = SizedBox(width: 60);
      if (isSelectedByMe) {
        trailingWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: _isProcessing ? null : _confirmSelection,
              tooltip: 'Confirm Spot',
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.red),
              onPressed: _isProcessing ? null : _cancelSelection,
              tooltip: 'Cancel Selection',
            ),
          ],
        );
      }

      ListTile listTile = ListTile(
        leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
        title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight)),
        trailing: trailingWidget,
        // Pass only necessary parameters to _selectSpot
        onTap: (isAvailable && !_isProcessing) ? () => _selectSpot(spotKey, isAvailable) : null,
        tileColor: isSelectedByMe ? Colors.blue.shade50 : null,
      );

      if (isTakenByMe) {
         return Dismissible(
            key: ValueKey(spotKey),
            direction: DismissDirection.endToStart,
            background: Container(
               color: Colors.red,
               padding: EdgeInsets.symmetric(horizontal: 20),
               alignment: Alignment.centerRight,
               child: Icon(Icons.delete_sweep, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
               return await _showRemoveConfirmationDialog(spotKey);
            },
            onDismissed: (direction) {
               _removeSignup(spotKey);
            },
            child: listTile,
         );
      } else {
         return listTile;
      }
    }

    // --- Building the list sections (Regular, Waitlist, Bucket) ---
    // (This part remains the same as before)

    // Add Regular Spots
    if (totalSpots > 0) {
       listItems.add(Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
         child: Text('Regular Spots', style: Theme.of(context).textTheme.titleMedium),
       ));
       for (int i = 0; i < totalSpots; i++) {
          String key = (i + 1).toString();
          listItems.add(buildSpotTile(i, SpotType.regular, key));
       }
       listItems.add(Divider());
    }


    // Add Waitlist Spots
    if (totalWaitlist > 0) {
      listItems.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text('Waitlist Spots', style: Theme.of(context).textTheme.titleMedium),
      ));
      for (int i = 0; i < totalWaitlist; i++) {
        String key = "W${i + 1}";
        listItems.add(buildSpotTile(i, SpotType.waitlist, key));
      }
      listItems.add(Divider());
    }

    // Add Bucket Spots
    if (totalBucket > 0) {
      listItems.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text('Bucket Spots', style: Theme.of(context).textTheme.titleMedium),
      ));
      for (int i = 0; i < totalBucket; i++) {
        String key = "B${i + 1}";
        listItems.add(buildSpotTile(i, SpotType.bucket, key));
      }
      listItems.add(Divider());
    }
    // --- End list section building ---

    return ListView(
      children: listItems,
    );
  }
}
// lib/pages/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/models/show.dart';
import 'package:cloud_functions/cloud_functions.dart';
// Removed collection import as MapEquality is not used

// Define SpotType enum if not globally available
enum SpotType { regular, waitlist, bucket }

class SignupScreen extends StatefulWidget {
  final String listId;
  const SignupScreen({super.key, required this.listId});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  late final String? _performerId;

  String? _performerStageName;
  bool _isLoadingPerformer = true;
  bool _isProcessing = false;
  bool _isBucketProcessing = false;
  String? _selectedSpotKey;
  bool _isUserAlreadyInBucket = false;
  bool _checkingBucketStatus = true;

  // Keep ValueNotifier if needed for other state, but not used here currently
  // final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier = ValueNotifier({});

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _performerId = _auth.currentUser?.uid;
    _fetchPerformerData();
    if (_performerId != null) {
      _checkBucketStatus();
    }
  }
    @override
    @mustCallSuper
    void dispose() {
      // _lastNotifiedPositionNotifier.dispose(); // Dispose if using ValueNotifier
      super.dispose();
    }

    // --- Data Fetching and Checks ---
    Future<void> _fetchPerformerData() async {
      setState(() {
        _isLoadingPerformer = true;
      });
      try {
        // Use final _auth and _performerId
        final user = _auth.currentUser; // Re-check just in case
        if (user != null && _performerId != null) {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(_performerId).get();
          if (mounted && userDoc.exists && userDoc.data() != null) {
            // Check mounted
            var userData = userDoc.data() as Map<String, dynamic>;
            _performerStageName =
                userData['stageName'] ?? user.email ?? 'Unknown Performer';
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
        if (mounted) {
          _performerStageName = 'Error'; // Avoid setState if not mounted
        }
        // Optionally show SnackBar if mounted
        // if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching profile: $e')));
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingPerformer = false;
          });
        }
      }
    }

    // --- End Data Fetching ---

    // --- Check if user is in bucket ---
    Future<void> _checkBucketStatus() async {
      if (_performerId == null || !mounted) return;
      setState(() {
        _checkingBucketStatus = true;
      });
      try {
        final provider = context.read<FirestoreProvider>();
        final bool isInBucket =
            await provider.isUserInBucket(widget.listId, _performerId!);
        if (mounted) {
          // Check mounted after await
          setState(() {
            _isUserAlreadyInBucket = isInBucket;
          });
        }
      } catch (e) {
        // print("Error checking bucket status: $e"); // Commented out
        if (mounted) {
          setState(() {
            _isUserAlreadyInBucket = false;
          }); // Assume not in bucket on error
        }
      } finally {
        if (mounted) {
          setState(() {
            _checkingBucketStatus = false;
          });
        }
      }
    }
    // --- End Check ---

    // --- Spot Logic (Select/Cancel/Confirm for Regular/Waitlist) ---
    void _selectSpot(String spotKey, bool isAvailable) {
      if (!isAvailable || _isLoadingPerformer || _performerStageName == null) {
        return;
      }
      setState(() {
        _selectedSpotKey = spotKey;
      });
    }

    void _cancelSelection() {
      setState(() {
        _selectedSpotKey = null;
      });
    }

  // --- MODIFIED: _confirmSelection to call Cloud Function ---
  Future<void> _confirmSelection() async {
    if (_selectedSpotKey == null ||
        // _performerStageName == null, // Cloud Function will fetch this
        _performerId == null ||
        _isProcessing ||
        !mounted) {
      return;
    }
    setState(() {
      _isProcessing = true;
    });

    // No need to read FirestoreProvider here for this specific action anymore
    // final firestoreProvider = context.read<FirestoreProvider>();
    // No need for listRef for direct transaction anymore
    // final listRef = _firestore.collection('Lists').doc(widget.listId);

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('manageSpotSignup');
    try {
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
        'listId': widget.listId,
        'spotKey': _selectedSpotKey!,
        'action': 'signup',
        // Performer stage name will be fetched by the Cloud Function from the user's profile
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message'] ?? 'Signed up successfully!'),
            backgroundColor: Colors.green));
        Navigator.of(context).pop(); // Go back or to list screen
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Failed to sign up. ${e.details ?? ''}'),
            backgroundColor: Colors.red));
        _cancelSelection(); // Clear selected spot on error
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('An unexpected error occurred during signup.'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

    // --- Bucket Join/Leave Logic ---
    Future<void> _toggleBucketSignup() async {
      if (_performerId == null ||
          _performerStageName == null ||
          _isBucketProcessing ||
          _checkingBucketStatus ||
          !mounted) {
        return;
      }

      setState(() {
        _isBucketProcessing = true;
      });
      final firestoreProvider = context.read<FirestoreProvider>();
      final listRef = _firestore.collection('Lists').doc(widget.listId);

      try {
        final listSnap = await listRef.get();
        final listData = listSnap.data() ?? {};
        final signedUpIds =
            List<String>.from(listData['signedUpUserIds'] ?? []);
        if (signedUpIds.contains(_performerId!)) {
          throw Exception(
              "Cannot join bucket list; you are already signed up for a main/waitlist spot.");
        }

        // Use the current state checked in initState/updated after action
        if (_isUserAlreadyInBucket) {
          await firestoreProvider.removeUserFromBucket(
              widget.listId, _performerId!);
          if (mounted) {
            setState(() {
              _isUserAlreadyInBucket = false;
            }); // Update local state
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Removed from bucket list.'),
                backgroundColor: Colors.orange));
          }
        } else {
          await firestoreProvider.addUserToBucket(
              widget.listId, _performerId!, _performerStageName!);
          if (mounted) {
            setState(() {
              _isUserAlreadyInBucket = true;
            }); // Update local state
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Joined bucket list!'),
                backgroundColor: Colors.green));
          }
        }
      } catch (e) {
        // print("Error toggling bucket signup: $e"); // Commented out
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isBucketProcessing = false;
          });
        }
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
           backgroundColor: Colors.white.withAlpha((255 * 0.95).round()),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title:
                Text('Confirm Removal', style: TextStyle(color: primaryColor)),
            content: Text(
                'Are you sure you want to remove yourself from spot $spotKey?',
                style: TextStyle(color: Colors.black87)),
            actions: <Widget>[
              TextButton(
                  child: Text('Cancel', style: TextStyle(color: appBarColor)),
                  onPressed: () => Navigator.of(context).pop(false)),
              TextButton(
                  child: Text('Remove',
                      style: TextStyle(color: Colors.red.shade700)),
                  onPressed: () => Navigator.of(context).pop(true)),
            ],
          );
        },
      );
    }

  // --- MODIFIED: _removeSignup to call Cloud Function ---
  Future<void> _removeSignup(String spotKey) async {
    if (_isProcessing || _performerId == null || !mounted) {
      return;
    }
    setState(() {
      _isProcessing = true;
    });

    // No need for FirestoreProvider here for this action
    // final firestoreProvider = context.read<FirestoreProvider>();

    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('manageSpotSignup');
    try {
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>({
        'listId': widget.listId,
        'spotKey': spotKey,
        'action': 'remove',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message'] ?? 'Successfully removed from spot.'),
            backgroundColor: Colors.orange));
        if (_selectedSpotKey == spotKey) _cancelSelection();
        // The StreamBuilder on the previous screen (PerformerListScreen) or this screen
        // will handle UI refresh based on Firestore data changes.
        // If this screen should pop after removal, add Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Failed to remove signup. ${e.details ?? ''}'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('An unexpected error occurred during removal.'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
        Widget _buildListContent(Show showData, bool isSignedUpOnMainList) {
        List<Widget> listItems = [];
        int overallIndex = 0;
        final spotsMap = showData.spots;
        final totalSpots = showData.numberOfSpots;
        final totalWaitlist = showData.numberOfWaitlistSpots;
        final totalBucket = showData.numberOfBucketSpots;

        // Define nested helpers inside or make them members of the State class if preferred
        Widget buildSectionHeader(String title, double delayMsDouble) {
          return FadeInDown(
            delay: Duration(milliseconds: delayMsDouble.round()),
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black.withAlpha(178))), // Use withAlpha
            ),
          );
        }

    // --- Modified buildSpotTile ---
    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey, int animationIndex) {
      final spotData = spotsMap[spotKey];
      bool isAvailable = spotData == null;
      bool isReserved = spotData is String && spotData == 'RESERVED';
      bool isTaken = !isAvailable && !isReserved;
      bool isTakenByMe = false; String takenByName = 'Taken';
      if (isTaken) { if (spotData is Map<String, dynamic>) { if (spotData['userId'] == _performerId) { isTakenByMe = true; takenByName = spotData['name'] ?? 'You'; } } else { takenByName = 'Error'; } }
      bool isSelectedByMe = _selectedSpotKey == spotKey;
      String titleText; Color titleColor = Colors.black; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;
      if (isSelectedByMe) { titleText = _performerStageName ?? 'Selecting...'; titleColor = Colors.blue; titleWeight = FontWeight.bold; }
      else if (isTakenByMe) { titleText = takenByName; titleWeight = FontWeight.bold; titleColor = Colors.black87; }
      else if (isTaken && !isTakenByMe) { titleText = 'Taken'; titleColor = Colors.grey.shade600; }
      else if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade700; }
      else if (isAvailable) { titleText = 'Available'; titleColor = Colors.green.shade800; }
      else { titleText = 'Unknown'; titleColor = Colors.red.shade900; }
      String spotLabel; switch (type) { case SpotType.regular: spotLabel = "${displayIndex + 1}."; break; case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break; case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break; }

      // --- Modified Trailing Widget Logic ---
      Widget? trailingWidget; // Make nullable
      if (isSelectedByMe) {
         // Show confirm/cancel when selecting an AVAILABLE spot
         trailingWidget = Row(mainAxisSize: MainAxisSize.min, children: [ IconButton(icon: Icon(Icons.check_circle, color: Colors.green), onPressed: _isProcessing ? null : _confirmSelection, tooltip: 'Confirm Spot'), IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: _isProcessing ? null : _cancelSelection, tooltip: 'Cancel Selection'), ]);
      } else if (isTakenByMe) {
         // Show only remove button if spot is taken by current user
         trailingWidget = IconButton(
            icon: Icon(Icons.cancel, color: Colors.red.shade700),
            tooltip: 'Remove Signup',
            // Trigger confirmation dialog on tap (same as ListTile onTap now)
            onPressed: _isProcessing ? null : () async {
               bool? confirm = await _showRemoveConfirmationDialog(spotKey);
               if (confirm == true) {
                  _removeSignup(spotKey);
               }
            },
         );
      } else {
         // No trailing widget for available (not selected), taken by other, or reserved
         trailingWidget = SizedBox(width: 48); // Keep space consistent if needed
      }
      // --- End Trailing Widget Logic ---

      // --- Build the ListTile inside a Card ---
      Widget listTileContent = Card(
         color: Colors.white.withAlpha((255 * 0.9).round()),
         elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         child: ListTile(
           leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
           title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
           trailing: trailingWidget, // Use the conditional trailing widget
           // --- Modified onTap Logic ---
           onTap: () async { // Make onTap async
              if (isAvailable && !_isProcessing) {
                 // Tap available spot: select it
                 _selectSpot(spotKey, isAvailable);
              } else if (isTakenByMe && !_isProcessing) {
                 // Tap own spot: show remove confirmation
                 bool? confirm = await _showRemoveConfirmationDialog(spotKey);
                 if (confirm == true) {
                    _removeSignup(spotKey);
                 }
              }
              // No action if tapped on reserved, taken by other, or while processing
           },
           // --- End Modified onTap ---
           tileColor: isSelectedByMe ? Colors.blue.shade50.withAlpha(200) : null,
         ),
      );

      // --- REMOVED Dismissible Wrapper ---
      // Widget finalTile;
      // if (isTakenByMe) { /* ... Dismissible ... */ } else { finalTile = listTileContent; }

      // Apply animation directly to the Card/ListTile content
      return FadeInUp( delay: Duration(milliseconds: (50 * animationIndex).round()), duration: const Duration(milliseconds: 300), child: listTileContent );
    }

        // --- Building the list sections ---
        if (totalSpots > 0) {
          listItems.add(
              buildSectionHeader('Regular Spots', overallIndex * 50.0 + 300.0));
          overallIndex++;
          for (int i = 0; i < totalSpots; i++) {
            listItems.add(buildSpotTile(
                i, SpotType.regular, (i + 1).toString(), overallIndex));
            overallIndex++;
          }
          if (totalWaitlist > 0 || totalBucket > 0) {
            listItems.add(Divider(
                indent: 16, endIndent: 16, color: Colors.white.withAlpha(128)));
          }
        }
        if (totalWaitlist > 0) {
          listItems.add(buildSectionHeader(
              'Waitlist Spots', overallIndex * 50.0 + 300.0));
          overallIndex++;
          for (int i = 0; i < totalWaitlist; i++) {
            listItems.add(
                buildSpotTile(i, SpotType.waitlist, "W${i + 1}", overallIndex));
            overallIndex++;
          }
          if (totalBucket > 0) {
            listItems.add(Divider(
                indent: 16, endIndent: 16, color: Colors.white.withAlpha(128)));
          }
        }
        if (totalBucket > 0) {
          listItems.add(Divider(
              indent: 16, endIndent: 16, color: Colors.white.withAlpha(128)));
          listItems.add(
              buildSectionHeader('Bucket Draw', overallIndex * 50.0 + 300.0));
          overallIndex++;
          listItems.add(FadeInUp(
            delay: Duration(milliseconds: (50 * overallIndex).round()),
            duration: const Duration(milliseconds: 400),
            child: Card(
              color: Colors.white.withAlpha((255 * 0.9).round()),
              elevation: 3,
              margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    StreamBuilder<int>(
                        stream: context
                            .read<FirestoreProvider>()
                            .getBucketSignupCountStream(widget.listId),
                        builder: (context, countSnapshot) {
                          int currentBucketSignups = countSnapshot.data ?? 0;
                          if (countSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !countSnapshot.hasData) {
                            return Text("Loading bucket count...",
                                style: TextStyle(color: Colors.grey.shade600));
                          }
                          return Text(
                            "Names in Bucket: $currentBucketSignups",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          );
                        }),
                    SizedBox(height: 15),
                    _checkingBucketStatus
                        ? CircularProgressIndicator(strokeWidth: 2)
                        : ElevatedButton.icon(
                            icon: Icon(
                                _isUserAlreadyInBucket
                                    ? Icons.person_remove_alt_1
                                    : Icons.person_add_alt_1,
                                color: Colors.white),
                            label: Text(_isUserAlreadyInBucket
                                ? 'Take Your Name Out of Bucket'
                                : 'Add Your Name to Bucket'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isUserAlreadyInBucket
                                  ? Colors.orange.shade700
                                  : Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed:
                                (_isBucketProcessing || isSignedUpOnMainList)
                                    ? null
                                    : _toggleBucketSignup,
                          ),
                    if (isSignedUpOnMainList)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "You are already signed up for a spot.",
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ));
        }
        // --- End list section building ---

        if (listItems.isEmpty) {
          return Center(
              child: Text("This list currently has no spots defined.",
                  style: TextStyle(color: Colors.black54)));
        }
        listItems.add(SizedBox(height: 20));
        return ListView(children: listItems); // Added return
      }
      // --- End Helper Widget ---

      // --- *** BUILD METHOD MUST BE LAST in State class *** ---
      @override
      Widget build(BuildContext context) {
        // Access provider needed for stream
        final firestoreProvider = context.watch<FirestoreProvider>();
        final Color appBarColor = Colors.blue.shade400;
        final Color primaryColor = Theme.of(context).primaryColor;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: appBarColor,
            elevation: 0,
            foregroundColor: Colors.white,
            title: StreamBuilder<Show>(
                // Use Show model stream
                stream: firestoreProvider.getShow(widget.listId),
                builder: (context, snapshot) {
                  if (snapshot.hasData) return Text(snapshot.data!.showName);
                  return Text('Signup List');
                }),
            leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop()),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.blue.shade200, Colors.purple.shade100])),
            child: _isLoadingPerformer
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : StreamBuilder<Show>(
                    // Use Show model stream here too
                    stream: firestoreProvider.getShow(widget.listId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Center(
                            child:
                                CircularProgressIndicator(color: primaryColor));
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error loading list: ${snapshot.error}',
                                style: TextStyle(color: Colors.red.shade900)));
                      }
                      if (!snapshot.hasData || snapshot.data == null) {
                        // Check for null data
                        return Center(
                            child: Text('List not found.',
                                style: TextStyle(color: Colors.black54)));
                      }

                      final showData = snapshot.data!; // Use Show object

                      // Check if user is already signed up for a main/waitlist spot
                      final bool isSignedUpOnMainList = _performerId != null &&
                          showData.signedUpUserIds.contains(_performerId);

                      // Call the helper function to build the list content
                      return _buildListContent(
                          showData, // Pass Show object
                          isSignedUpOnMainList);
                    },
                  ),
          ),
        );
      }
    }

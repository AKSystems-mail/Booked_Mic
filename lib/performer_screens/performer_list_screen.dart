// lib/pages/performer_screens/performer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:intl/intl.dart'; // Import DateFormat
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform; // To check the platform

// Import necessary screens
import '../../role_selection_screen.dart';
import 'signup_screen.dart';
import '../../registration_screen.dart';

// bool _isListSearchable = true;

class PerformerListScreen extends StatefulWidget {
  PerformerListScreen({Key? key}) : super(key: key);

  @override
  _PerformerListScreenState createState() => _PerformerListScreenState();
}

class _PerformerListScreenState extends State<PerformerListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSearchState;
    static const String _lastSelectedStateKey = 'last_selected_search_state'; // Key for SharedPreferences
  final List<String> usStates = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
    'DC'
  ];

  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  @override
  void initState() {
    super.initState();
    _loadLastSelectedState(); // Load on init
  }

  @override
  void dispose() {
    _lastNotifiedPositionNotifier.dispose();
    super.dispose();
  }

  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }

  Future<void> _loadLastSelectedState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastState = prefs.getString(_lastSelectedStateKey);
    if (lastState != null && mounted) {

    }
  }

  Future<void> _saveLastSelectedState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedStateKey, state);
  }

  Future<void> _showStateSearchDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String? previouslySelectedState = prefs.getString(_lastSelectedStateKey);

    // Local state for the dialog's search functionality
    String searchQuery = '';
    List<String> filteredStates = List.from(usStates); // Start with all states

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to allow updating the dialog's content (filtered list)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter states based on searchQuery
            if (searchQuery.isEmpty) {
              filteredStates = List.from(usStates);
            } else {
              filteredStates = usStates
                  .where((s) => s.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();
            }

            return AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.98), // Slightly more opaque
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Search State', style: TextStyle(color: Theme.of(context).primaryColor)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.7, // Increased height a bit
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Type to search states...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        onChanged: (value) {
                          setDialogState(() { // Update dialog state to re-filter
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredStates.isEmpty
                          ? Center(child: Text('No states found for "$searchQuery"'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredStates.length,
                              itemBuilder: (context, index) {
                                final state = filteredStates[index];
                                bool isPreviouslySelected = state == previouslySelectedState;
                                return ListTile(
                                  title: Text(
                                    state,
                                    style: TextStyle(
                                      fontWeight: isPreviouslySelected ? FontWeight.bold : FontWeight.w500,
                                      color: isPreviouslySelected ? Theme.of(context).primaryColor : Colors.black87,
                                    ),
                                  ),
                                  tileColor: isPreviouslySelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onTap: () => Navigator.of(dialogContext).pop(state),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) { // Only update if a state was actually selected
      if (result != _selectedSearchState) { // And if it's different from current search
        setState(() {
          _selectedSearchState = result;
        });
      }
      await _saveLastSelectedState(result); // Save the newly selected state
    }
  }

  void _toggleSearch() {
    if (_selectedSearchState == null) {
      _showStateSearchDialog();
    } else {
      setState(() {
        _selectedSearchState = null;
      });
    }
  }

  // --- REPLACE your old _showPositionNotification with this new one ---
  Future<void> _showCustomPositionNotification(
      String listId, String listName, int currentPositionIndex, int totalActivePerformers) async {
    if (!mounted) return;

    String title = 'Spot Update: $listName';
    String body = '';
    bool playHapticFeedback = false;

    if (currentPositionIndex == 0) { // 0-based index: 0 means "up next"
      body = "You're up next!";
      playHapticFeedback = true;
    } else if (currentPositionIndex == 1) {
      body = "There is 1 performer ahead of you.";
    } else if (currentPositionIndex > 1) {
      body = "There are $currentPositionIndex performers ahead of you.";
    } else {
      // currentPositionIndex is -1 (not in active list) or something unexpected.
      // You might want a notification if they are dropped from the active list,
      // or just return if no notification is needed for this case.
      // For now, let's assume if currentPositionIndex is not >= 0, no "position" notification.
      return;
    }

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: listId.hashCode + currentPositionIndex + DateTime.now().millisecondsSinceEpoch, // More unique ID
          channelKey: 'spot_updates_channel',
          title: title,
          body: body,
          payload: {'listId': listId, 'spot': (currentPositionIndex + 1).toString()},
          notificationLayout: NotificationLayout.Default,
        // locked: playHapticFeedback, // Optional: if you want "up next" to be sticky
        // autoDismissible: !playHapticFeedback, // Optional
        ),
      );

    if (playHapticFeedback && mounted) {
      HapticFeedback.heavyImpact();
    }
    } catch (e) {
      print("Error showing custom position notification: $e");
    }
  }


  // --- MODIFIED _updateAndNotifyPositions ---
  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs) {
    if (!mounted || currentUserId == null) return;
    final today = DateTime.now();
    final Map<String, int?> currentPositions = {};
    // final Map<String, String> listIdToNameMap = {}; // Not strictly needed if passing listName directly

    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listId = doc.id;
      final String listName = listData['listName'] ?? 'Unnamed List'; // Get list name

      final Timestamp? showTimestamp = listData['date'] as Timestamp?;
      if (showTimestamp != null) {
        final showDate = showTimestamp.toDate();
        if (showDate.year == today.year &&
            showDate.month == today.month &&
            showDate.day == today.day) {
          final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
          final numRegular = (listData['numberOfSpots'] ?? 0) as int;
          final numWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
          
          List<String> activePerformers = [];

          // Helper to check spot and add to activePerformers
          // This local helper is fine.
          checkSpot(String key) {
            if (spotsMap.containsKey(key)) {
              final d = spotsMap[key];
              if (d is Map && d['userId'] != null && !(d['isOver'] == true)) {
                activePerformers.add(d['userId'] as String);
              }
            }
          }

          // Build activePerformers list in order
          for (int i = 1; i <= numRegular; i++) {
            checkSpot(i.toString());
          }
          for (int i = 1; i <= numWaitlist; i++) {
            checkSpot("W$i");
          }
          // --- End building activePerformers ---

          final int currentPositionIndex = activePerformers.indexOf(currentUserId!); // 0-based

          currentPositions[listId] = currentPositionIndex; // Store 0-based index

          if (currentPositionIndex != -1) { // User is in the active list
            final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

            if (lastNotifiedPosition == null || lastNotifiedPosition != currentPositionIndex) {
              // Position has changed or it's the first notification for this list today
              _showCustomPositionNotification( // <<< CALL THE NEW FUNCTION
                  listId,
                  listName,
                  currentPositionIndex, // This is the number of people ahead (0 means next)
                  activePerformers.length);
            }
          }
        }
      }
    }

    // Update _lastNotifiedPositionNotifier
    final Map<String, int?> nextNotifierValue = Map.from(_lastNotifiedPositionNotifier.value);
    currentPositions.forEach((listId, position) {
      if (position != -1) { // Only store valid positions
        nextNotifierValue[listId] = position;
      } else { // User is no longer in the active list for this listId
        nextNotifierValue.remove(listId);
      }
    });
    // Also remove any lists from notifier that are no longer in `docs` (e.g., user left list entirely)
    List<String> currentListIdsInDocs = docs.map((d) => d.id).toList();
    _lastNotifiedPositionNotifier.value.keys
        .where((id) => !currentListIdsInDocs.contains(id))
        .toList()
        .forEach(nextNotifierValue.remove);


    if (!const MapEquality().equals(_lastNotifiedPositionNotifier.value, nextNotifierValue)) {
      _lastNotifiedPositionNotifier.value = nextNotifierValue;
    }
  }

  Future<void> _launchMaps(String address) async {
  if (address.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address is not available.')),
      );
    }
    return;
  }

  // Log the address being used
  String query = Uri.encodeComponent(address);

  Uri? platformSpecificUri;
  bool launchedSuccessfully = false;

  if (Platform.isAndroid) {
    platformSpecificUri = Uri.parse('geo:0,0?q=$query');
  } else if (Platform.isIOS) {
    platformSpecificUri = Uri.parse('maps://maps.apple.com/?q=$query');
  }

  // Try platform-specific URI first
  if (platformSpecificUri != null) {
    try {
      if (await canLaunchUrl(platformSpecificUri)) {
        await launchUrl(platformSpecificUri);
        launchedSuccessfully = true;
      } else {
      }
    } catch (e) {
    }
  }

  // If platform-specific launch failed or wasn't applicable, try web fallback
  if (!launchedSuccessfully) {
    Uri webMapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      // For web, we often don't need to check canLaunchUrl for https if a browser is expected.
      // But it's safer to keep it.
      if (await canLaunchUrl(webMapUri)) {
        await launchUrl(webMapUri, mode: LaunchMode.externalApplication);
        launchedSuccessfully = true;
      } else {
      }
    } catch (e) {
      print("Error launching web fallback URI ($webMapUri): $e");
    }
  }

  if (!launchedSuccessfully) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps app or website.')),
      );
    }
  }
}


  Widget _buildListSection(BuildContext context, String title, List<DocumentSnapshot> docs, bool showSpotNumber) {
     if (docs.isEmpty) {
        return const SizedBox.shrink();
     }
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
             padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
             child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black.withAlpha(200))),
           ),
           ListView.builder(
             shrinkWrap: true,
             physics: NeverScrollableScrollPhysics(),
             itemCount: docs.length,
             itemBuilder: (context, index) {
               final doc = docs[index];
               final listData = doc.data() as Map<String, dynamic>? ?? {};
               final String docId = doc.id;
               String displayStatus = "In Bucket Draw";

               final Timestamp? showTimestamp = listData['date'] as Timestamp?;
               String formattedDate = '';
               if (showTimestamp != null) {
                 formattedDate = DateFormat('EEE, MMM d').format(showTimestamp.toDate());
               }

               if (showSpotNumber) {
                  displayStatus = "Unknown Spot";
                  final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                  spotsMap.forEach((key, value) {
                    if (value is Map && value['userId'] == currentUserId) {
                      displayStatus = "Spot: $key";
                    }
                  });
               }

               String addressText = listData['address'] ?? 'No Address Provided';

               return FadeInUp(
                 delay: Duration(milliseconds: 100 * index),
                 duration: const Duration(milliseconds: 400),
                 child: Card(
                   color: Colors.white.withAlpha((255 * 0.9).round()),
                   elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   child: ListTile(
                     title: Text(
                        listData['listName'] ?? 'Unnamed List',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                     ),
                     // --- MODIFIED SUBTITLE TO INCLUDE MAP ICON ---
                     subtitle: Row(
                       children: [
                         Expanded(
                           child: Text(
                             addressText,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ),
                         // Only show map icon if address is not 'No Address Provided' and not empty
                         if (addressText != 'No Address Provided' && addressText.trim().isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(left: 8.0),
                             child: IconButton(
                               icon: Icon(Icons.directions_outlined, color: Theme.of(context).primaryColor), // Or Icons.map_outlined
                               iconSize: 22.0,
                               padding: EdgeInsets.zero,
                               constraints: BoxConstraints(), // To make the tap area tighter
                               tooltip: 'Get Directions',
                               onPressed: () {
                                 _launchMaps(addressText);
                               },
                             ),
                           ),
                       ],
                     ),
                     trailing: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: <Widget>[
                         if (formattedDate.isNotEmpty)
                           Text(
                             formattedDate,
                             style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                           ),
                         if (formattedDate.isNotEmpty && displayStatus.isNotEmpty)
                           SizedBox(height: 4.0),
                         Text(
                           displayStatus,
                           style: TextStyle(
                             fontStyle: !showSpotNumber ? FontStyle.italic : FontStyle.normal,
                             color: Colors.grey.shade700,
                             fontSize: 12,
                           ),
                         ),
                       ],
                     ),
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                   ),
                 ),
               );
             },
           ),
        ],
     );
  }

  Widget _buildMySignupsView() {
    if (currentUserId == null) {
      return Center(
          child:
              Text("Not logged in.", style: TextStyle(color: Colors.black54)));
    }

    final onListStream = _firestore
        .collection('Lists')
        .where('signedUpUserIds', arrayContains: currentUserId)
        .orderBy('date', descending: false)
        .snapshots();

    final bucketSignupsStream = _firestore
        .collectionGroup('bucketSignups')
        .where('userId', isEqualTo: currentUserId)
        .snapshots();

    return ListView(
      padding: EdgeInsets.only(bottom: 80.0),
      children: [
        StreamBuilder<QuerySnapshot>(
            stream: onListStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.blue.shade600)));
              }
              if (snapshot.hasError) {
                return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: Text('Error loading lists: ${snapshot.error}',
                            style: TextStyle(color: Colors.red.shade900))));
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  _updateAndNotifyPositions(snapshot.data!.docs);
                }
              });
              return _buildListSection(
                  context, "Lists You're On", snapshot.data?.docs ?? [], true);
            }),
        StreamBuilder<QuerySnapshot>(
            stream: bucketSignupsStream,
            builder: (context, bucketSnapshot) {
              if (bucketSnapshot.connectionState == ConnectionState.waiting &&
                  !bucketSnapshot.hasData) {
                return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.blue.shade600)));
              }
              if (bucketSnapshot.hasError) {
                return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                        child: Text(
                            'Error loading bucket signups: ${bucketSnapshot.error}',
                            style: TextStyle(color: Colors.red.shade900))));
              }
              if (!bucketSnapshot.hasData || bucketSnapshot.data!.docs.isEmpty)
                return SizedBox.shrink();

              final List<String> bucketListIds = bucketSnapshot.data!.docs
                  .map((doc) => doc.reference.parent.parent?.id)
                  .where((id) => id != null)
                  .cast<String>()
                  .toSet()
                  .toList();

              if (bucketListIds.isEmpty) return SizedBox.shrink();

              return FutureBuilder<List<DocumentSnapshot>>(
                  future: bucketListIds.isNotEmpty
                      ? Future.wait(bucketListIds.map(
                          (id) => _firestore.collection('Lists').doc(id).get()))
                      : Future.value([]),
                  builder: (context, listDocsSnapshot) {
                    if (listDocsSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !listDocsSnapshot.hasData) {
                      return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue.shade600)));
                    }
                    if (listDocsSnapshot.hasError) {
                      return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                              child: Text(
                                  'Error loading bucket list details: ${listDocsSnapshot.error}',
                                  style:
                                      TextStyle(color: Colors.red.shade900))));
                    }
                    if (!listDocsSnapshot.hasData ||
                        listDocsSnapshot.data!.isEmpty)
                      return SizedBox.shrink();

                    final validListDocs = listDocsSnapshot.data!
                        .where((doc) => doc.exists)
                        .toList();
                    validListDocs.sort((a, b) {
                      Timestamp? dateA = (a.data()
                          as Map<String, dynamic>?)?['date'] as Timestamp?;
                      Timestamp? dateB = (b.data()
                          as Map<String, dynamic>?)?['date'] as Timestamp?;
                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;
                      return dateB.compareTo(dateB);
                    });

                    return _buildListSection(
                        context, "Buckets You're In", validListDocs, false);
                  });
            }),
      ],
    );
  }

  Widget _buildSearchResultsBasedOnState(String state) {
    return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('Lists')
            .where('state', isEqualTo: state.toUpperCase())
            .where('isSearchable', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
                child: CircularProgressIndicator(color: Colors.blue.shade600));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error searching lists: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade900)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('No open lists found for state \"$state\".',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16))); // Corrected quote
          }

          return ListView.builder(
            padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final listData = doc.data() as Map<String, dynamic>? ?? {};
              final String docId = doc.id;

              final Timestamp? showTimestamp = listData['date'] as Timestamp?;
              String formattedDate = '';
              if (showTimestamp != null) {
                formattedDate =
                    DateFormat('EEE, MMM d').format(showTimestamp.toDate());
              }

              final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
              final filledSpotsCount = spotsMap.values.whereType<Map>().length;
              final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
              final waitlistSpots =
                  (listData['numberOfWaitlistSpots'] ?? 0) as int;
              // final bucketSpots = (listData['numberOfBucketSpots'] ?? 0) as int; // Not directly used for 'Open Spots' count
              int totalDefinedSpots = regularSpots + waitlistSpots;

              return FadeInUp(
                delay: Duration(milliseconds: 100 * index),
                duration: const Duration(milliseconds: 400),
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  elevation: 3,
                  margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(listData['listName'] ?? 'Unnamed List',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (formattedDate.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(formattedDate,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    subtitle: Text(listData['address'] ?? 'No Address Provided',
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(
                        'Open Spots: $filledSpotsCount/$totalDefinedSpots'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SignupScreen(listId: docId))),
                  ),
                ),
              );
            },
          );
        });
  }

  Future<void> _scanQrCode() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      var res = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const SimpleBarcodeScannerPage()));
      if (res is String && res != "-1" && res.isNotEmpty && mounted) {
        String scannedListId = res;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SignupScreen(listId: scannedListId)));
      }
    } else if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Camera permission permanently denied. Please enable it in settings.')));
      await openAppSettings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Camera permission is required to scan QR codes.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color fabColor = appBarColor;
    if (currentUserId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => RegistrationScreen()),
              (Route<dynamic> route) => false);
        }
      });
      return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(_selectedSearchState == null
            ? 'My Signups'
            : 'Open Lists: $_selectedSearchState'),
        actions: [
          Tooltip(
              message: _selectedSearchState == null
                  ? 'Search by State'
                  : 'Clear Search ($_selectedSearchState)',
              child: IconButton(
                  icon: Icon(_selectedSearchState == null
                      ? Icons.search
                      : Icons.search_off),
                  onPressed: _toggleSearch)),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _switchRole(context),
              icon: Icon(Icons.sync_alt, size: 20.0, color: Colors.white),
              label: Text('Switch Role',
                  style: TextStyle(fontSize: 14.0, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                colors: [Colors.blue.shade200, Colors.purple.shade100])),
        child: _selectedSearchState == null
            ? _buildMySignupsView()
            : _buildSearchResultsBasedOnState(_selectedSearchState!),
      ),
      floatingActionButton: FadeInUp(
        delay: Duration(milliseconds: 600),
        child: FloatingActionButton(
          onPressed: _scanQrCode,
          backgroundColor: fabColor,
          foregroundColor: Colors.white,
          tooltip: 'Scan List QR Code',
          child: Icon(Icons.qr_code_scanner),
        ),
      ),
    );
  }
}

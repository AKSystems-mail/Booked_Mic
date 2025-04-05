// lib/pages/performer_screens/performer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:collection/collection.dart'; // Import for MapEquality
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

// Import necessary screens
import '../../role_selection_screen.dart';
import 'signup_screen.dart';
import '../../registration_screen.dart';
// Import main to access the global plugin instance

// Access the global instance from main.dart
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class PerformerListScreen extends StatefulWidget {
  PerformerListScreen({Key? key}) : super(key: key);

  @override
  _PerformerListScreenState createState() => _PerformerListScreenState();
}

class _PerformerListScreenState extends State<PerformerListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSearchState;

  final List<String> usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC'
  ];

  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  @override
  void initState() {
    super.initState();
    _notificationsPlugin = flutterLocalNotificationsPlugin;
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
      context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }

  Future<void> _showStateSearchDialog() async {
    final String? result = await showDialog<String>(
       context: context,
       builder: (BuildContext context) {
          final Color primaryColor = Theme.of(context).primaryColor;
          final Color appBarColor = Colors.blue.shade400;
          return AlertDialog(
             backgroundColor: Colors.white.withOpacity(0.95), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
             title: Text('Search by State', style: TextStyle(color: primaryColor)),
             content: Container(width: double.maxFinite, height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(shrinkWrap: true, itemCount: usStates.length, itemBuilder: (context, index) { final state = usStates[index]; return ListTile(title: Text(state, style: TextStyle(fontWeight: FontWeight.w500)), onTap: () => Navigator.of(context).pop(state)); }),
             ),
             actions: <Widget>[ TextButton(child: Text('Cancel', style: TextStyle(color: appBarColor)), onPressed: () => Navigator.of(context).pop())],
          );
       }
    );
    if (result != null && result != _selectedSearchState) {
       setState(() { _selectedSearchState = result; });
    }
  }

  void _toggleSearch() {
     if (_selectedSearchState == null) {
        _showStateSearchDialog();
     } else {
        setState(() { _selectedSearchState = null; });
     }
  }

  Future<void> _showPositionNotification(String listId, String listName, int positionIndex) async {
     String body = "";
     if (positionIndex == 0) body = "You're up next!";
     else if (positionIndex == 1) body = "1 performer ahead of you.";
     else body = "$positionIndex performers ahead of you.";
     const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('list_position_channel', 'List Position Updates', channelDescription: 'Notifications about your position in performance lists', importance: Importance.max, priority: Priority.high, ticker: 'ticker');
     const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(presentSound: true, presentBadge: true, presentAlert: true);
     const NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
     await _notificationsPlugin.show(listId.hashCode, 'Update: $listName', body, platformDetails, payload: listId);
     print("Local notification shown for $listId: $body");
  }

  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs) {
     if (!mounted || currentUserId == null) return;
     final today = DateTime.now();
     final Map<String, int?> currentPositions = {};
     docs.forEach((doc) {
        final listData = doc.data() as Map<String, dynamic>? ?? {};
        final String listId = doc.id;
        final Timestamp? showTimestamp = listData['date'] as Timestamp?;
        if (showTimestamp != null) {
           final showDate = showTimestamp.toDate();
           if (showDate.year == today.year && showDate.month == today.month && showDate.day == today.day) {
              final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
              final numRegular = (listData['numberOfSpots'] ?? 0) as int;
              final numWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
              final numBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
              final List<String> activePerformers = [];
              final checkSpot = (String key) { if (spotsMap.containsKey(key)) { final d = spotsMap[key]; if (d is Map && d['userId'] != null && !(d['isOver'] == true)) activePerformers.add(d['userId']); }};
              for (int i = 1; i <= numRegular; i++) checkSpot(i.toString());
              for (int i = 1; i <= numWaitlist; i++) checkSpot("W$i");
              for (int i = 1; i <= numBucket; i++) checkSpot("B$i");
              final currentPositionIndex = activePerformers.indexOf(currentUserId!);
              currentPositions[listId] = currentPositionIndex;
              if (currentPositionIndex != -1) {
                 final lastPosition = _lastNotifiedPositionNotifier.value[listId];
                 if (lastPosition == null || lastPosition != currentPositionIndex) {
                    print("Position change detected for $listId: $lastPosition -> $currentPositionIndex");
                    final String listName = listData['listName'] ?? 'Unnamed List';
                    _showPositionNotification(listId, listName, currentPositionIndex);
                 }
              }
           }
        }
     });
     final Map<String, int?> nextNotifierValue = {};
     _lastNotifiedPositionNotifier.value.forEach((listId, position) { if (currentPositions.containsKey(listId) && currentPositions[listId] != null) nextNotifierValue[listId] = currentPositions[listId]; });
     currentPositions.forEach((listId, position) { if (position != null && !nextNotifierValue.containsKey(listId)) nextNotifierValue[listId] = position; });
     if (!MapEquality().equals(_lastNotifiedPositionNotifier.value, nextNotifierValue)) { print("Updating tracked positions: $nextNotifierValue"); _lastNotifiedPositionNotifier.value = nextNotifierValue; }
     else { print("No change in overall tracked positions."); }
  }

  // --- Widget for Signed-up Lists ---
  Widget _buildSignedUpLists() {
    if (currentUserId == null) return Center(child: Text("Not logged in.", style: TextStyle(color: Colors.black54)));
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Lists').where('signedUpUserIds', arrayContains: currentUserId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.blue.shade600));
        if (snapshot.hasError) return Center(child: Text('Error loading your lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('You haven\'t signed up for any lists yet.', style: TextStyle(color: Colors.black54, fontSize: 16)));
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateAndNotifyPositions(snapshot.data!.docs));
        return ListView.builder(
          padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final listData = doc.data() as Map<String, dynamic>? ?? {};
            final String docId = doc.id;
            String mySpot = "Unknown Spot";
            final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
            spotsMap.forEach((key, value) { if (value is Map && value['userId'] == currentUserId) mySpot = key; });
            return FadeInUp(
              delay: Duration(milliseconds: 100 * index), duration: const Duration(milliseconds: 400),
              child: Card(
                color: Colors.white.withOpacity(0.9), elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(listData['listName'] ?? 'Unnamed List', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(listData['address'] ?? 'No Address Provided'),
                  trailing: Text("Your Spot: $mySpot"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Widget for State Search Results ---
  // This function IS CALLED by the build method when _selectedSearchState is not null
  Widget _buildSearchResultsBasedOnState(String state) {
     return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Lists').where('state', isEqualTo: state.toUpperCase()).orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Colors.blue.shade600));
           if (snapshot.hasError) return Center(child: Text('Error searching lists: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text('No open lists found for state "$state".', style: TextStyle(color: Colors.black54, fontSize: 16)));
           return ListView.builder(
             padding: EdgeInsets.only(top: 8.0, bottom: 80.0),
             itemCount: snapshot.data!.docs.length,
             itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final listData = doc.data() as Map<String, dynamic>? ?? {};
                final String docId = doc.id;
                final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
                final filledSpotsCount = spotsMap.values.whereType<Map>().length;
                final regularSpots = (listData['numberOfSpots'] ?? 0) as int;
                final waitlistSpots = (listData['numberOfWaitlistSpots'] ?? 0) as int;
                final bucketSpots = (listData['numberOfBucketSpots'] ?? 0) as int;
                final totalSpots = regularSpots + waitlistSpots + bucketSpots;
                return FadeInUp(
                   delay: Duration(milliseconds: 100 * index), duration: const Duration(milliseconds: 400),
                   child: Card(
                     color: Colors.white.withOpacity(0.9), elevation: 3, margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     child: ListTile(
                       title: Text(listData['listName'] ?? 'Unnamed List', style: TextStyle(fontWeight: FontWeight.bold)),
                       subtitle: Text(listData['address'] ?? 'No Address Provided'),
                       trailing: Text('Spots: $filledSpotsCount/$totalSpots'),
                       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: docId))),
                     ),
                   ),
                );
             },
           );
        }
     );
  }


  // --- Updated Function to Handle Scan Button Press ---
  Future<void> _scanQrCode() async {
     var status = await Permission.camera.request();
     if (status.isGranted) {
        if (!mounted) return;
        var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
        if (res is String && res != "-1" && res.isNotEmpty && mounted) {
           String scannedListId = res;
           print("QR Scan Result (List ID): $scannedListId");
           // TODO: Optional: Add Firestore check for list existence
           Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(listId: scannedListId)));
        } else { print("Scan cancelled or failed (Result: $res)"); }
     } else if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera permission permanently denied. Please enable it in settings.')));
        await openAppSettings();
     } else if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera permission is required to scan QR codes.')));
     }
  }
  // --- End Scan Function ---


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color fabColor = appBarColor;
    if (currentUserId == null) {
       WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => RegistrationScreen()), (Route<dynamic> route) => false); });
       return Scaffold(body: Center(child: Text("Redirecting...")));
    }

    return Scaffold(
      appBar: AppBar(
         backgroundColor: appBarColor, elevation: 0, foregroundColor: Colors.white,
         title: Text(_selectedSearchState == null ? 'My Signups' : 'Open Lists: $_selectedSearchState'),
         actions: [
            Tooltip(message: _selectedSearchState == null ? 'Search by State' : 'Clear Search ($_selectedSearchState)', child: IconButton(icon: Icon(Icons.search), onPressed: _toggleSearch)),
            Tooltip(message: 'Switch Role', child: IconButton(icon: Icon(Icons.switch_account), onPressed: () => _switchRole(context))),
         ],
      ),
      body: Container(
         width: double.infinity, height: double.infinity,
         decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100])),
         child: _selectedSearchState == null
             ? _buildSignedUpLists()
             : _buildSearchResultsBasedOnState(_selectedSearchState!), // This function IS used
      ),
      floatingActionButton: FadeInUp(
         delay: Duration(milliseconds: 600),
         child: FloatingActionButton(
           onPressed: _scanQrCode, // This function IS used
           backgroundColor: fabColor, foregroundColor: Colors.white,
           tooltip: 'Scan List QR Code', child: Icon(Icons.qr_code_scanner),
         ),
      ),
    );
  }
}
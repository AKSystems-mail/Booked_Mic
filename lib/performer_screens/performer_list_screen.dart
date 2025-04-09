// lib/pages/performer_screens/performer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
// --- Import Awesome Notifications ---
import 'package:awesome_notifications/awesome_notifications.dart';
// --- End Import ---
import 'package:collection/collection.dart'; // Import for MapEquality
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

// Import necessary screens
import '../../role_selection_screen.dart';
import 'signup_screen.dart';
import '../../registration_screen.dart';
// No longer need to import main.dart specifically for the plugin instance

// --- REMOVED flutter_local_notifications plugin instance ---

class PerformerListScreen extends StatefulWidget {
  PerformerListScreen({Key? key}) : super(key: key);

  @override
  _PerformerListScreenState createState() => _PerformerListScreenState();
}

class _PerformerListScreenState extends State<PerformerListScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSearchState;

  final List<String> usStates = [ /* ... List of states ... */ ];

  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  // --- REMOVED local notification plugin variable ---
  // late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  @override
  void initState() {
    super.initState();
    // --- REMOVED local plugin assignment ---

    // --- Awesome Notifications: Set up listener for notification actions ---
    AwesomeNotifications().setListeners(
        onActionReceivedMethod:         NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod:    NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:  NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod:  NotificationController.onDismissActionReceivedMethod
    );
    // --- End Listener Setup ---
  }

  @override
  void dispose() {
    _lastNotifiedPositionNotifier.dispose();
    super.dispose();
  }

  // --- Methods (_switchRole, _showStateSearchDialog, _toggleSearch) remain the same ---
  Future<void> _switchRole(BuildContext context) async { /* ... */ }
  Future<void> _showStateSearchDialog() async { /* ... */ }
  void _toggleSearch() { /* ... */ }

  // --- Updated Helper to Show Notification using Awesome Notifications ---
  Future<void> _showPositionNotification(String listId, String listName, int positionIndex) async {
     String body = "";
     if (positionIndex == 0) body = "You're up next!";
     else if (positionIndex == 1) body = "1 performer ahead of you.";
     else body = "$positionIndex performers ahead of you.";

     try {
        await AwesomeNotifications().createNotification(
           content: NotificationContent(
              id: listId.hashCode, // Unique ID for this notification
              channelKey: 'spot_updates_channel', // MUST match channel defined in main.dart
              title: 'Update: $listName',
              body: body,
              // Optional: Add payload to handle taps
              payload: {'listId': listId},
              notificationLayout: NotificationLayout.Default, // Or BigText etc.
              // locked: true, // Optional: Make persistent until dismissed
              // autoDismissible: false, // Optional: Prevent auto dismiss
           ),
           // Optional: Add action buttons
           // actionButtons: [
           //    NotificationActionButton(key: 'VIEW_LIST', label: 'View List')
           // ]
        );
        print("Awesome notification created for $listId: $body");
     } catch (e) {
        print("Error creating awesome notification: $e");
     }
  }
  // --- End Helper ---

  // --- Position Calculation & Notification Logic --- (No changes needed inside)
  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs) { /* ... */ }
  // --- End Position Logic ---


  // --- Widget for Signed-up Lists --- (No changes needed inside)
  Widget _buildSignedUpLists() { /* ... */ }

  // --- Widget for State Search Results --- (No changes needed inside)
  Widget _buildSearchResultsBasedOnState(String state) { /* ... */ }


  // --- Scan Function --- (No changes needed inside)
  Future<void> _scanQrCode() async { /* ... */ }
  // --- End Scan Function ---


  @override
  Widget build(BuildContext context) {
    // ... (AppBar, Body Container, FAB remain the same) ...
     final Color appBarColor = Colors.blue.shade400;
     final Color fabColor = appBarColor;
     if (currentUserId == null) { /* ... Fallback ... */ }

     return Scaffold(
       appBar: AppBar( /* ... */ ),
       body: Container( /* ... Gradient & Body ... */ ),
       floatingActionButton: FadeInUp( /* ... FAB ... */ ),
     );
  }
}


// --- Awesome Notifications Controller (Required) ---
// This class handles notification events. Put it in a separate file or at the
// bottom of main.dart if preferred, but it needs to be accessible globally
// or its static methods need to be top-level functions.
class NotificationController {

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future <void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    // Your code goes here
    print('NOTIFICATION CREATED: ${receivedNotification.id}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future <void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    // Your code goes here
    print('NOTIFICATION DISPLAYED: ${receivedNotification.id}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future <void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    // Your code goes here
    print('NOTIFICATION DISMISSED: ${receivedAction.id}');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future <void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // Your code goes here
    print('NOTIFICATION ACTION RECEIVED: ${receivedAction.id}');
    final payload = receivedAction.payload;
    if (payload != null) {
       print('Payload: $payload');
       // Navigate to the correct screen based on the payload
       // IMPORTANT: This navigation needs access to a Navigator key or similar
       // mechanism if triggered from a background isolate. You might need
       // to use a stream/event bus or store the target route in shared prefs
       // to be handled when the app resumes.
       // Example (won't work directly from background isolate):
       // if (payload.containsKey('listId')) {
       //    String listId = payload['listId']!;
       //    // Navigator.of(context)... <-- Need context or navigator key
       // }
    }
  }
}
// --- End Notification Controller ---
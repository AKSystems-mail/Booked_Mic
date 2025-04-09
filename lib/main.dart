// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
// --- Import Awesome Notifications ---
import 'package:awesome_notifications/awesome_notifications.dart';
// --- End Import ---
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import your screen widgets
import 'firebase_options.dart';
import 'registration_screen.dart'; // Keep imports for routes/AuthWrapper
import 'role_selection_screen.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';

// --- REMOVED flutter_local_notifications instance ---
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
     await dotenv.load(fileName: ".env");
     print(".env file loaded successfully.");
  } catch (e) {
     print("Error loading .env file: $e");
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- Awesome Notifications Initialization ---
  await AwesomeNotifications().initialize(
    // Set the icon to null to use the default app icon
    null, // Or 'resource://drawable/res_app_icon' if you have one
    [ // Define Notification Channels
      NotificationChannel(
        channelGroupKey: 'basic_channel_group',
        channelKey: 'spot_updates_channel', // Channel key used in performer_list_screen
        channelName: 'List Position Updates',
        channelDescription: 'Notifications about your position in performance lists',
        defaultColor: Colors.blue.shade400, // Use a theme color
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        // soundSource: 'resource://raw/res_custom_sound', // Optional
      )
    ],
    // Optional channel groups:
    channelGroups: [
      NotificationChannelGroup(
        channelGroupKey: 'basic_channel_group',
        channelGroupName: 'Basic group')
    ],
    debug: true, // Enable debug logs during development
  );

  // Set up listeners for notification actions (important for handling taps)
  AwesomeNotifications().setListeners(
      onActionReceivedMethod:         NotificationController.onActionReceivedMethod,
      onNotificationCreatedMethod:    NotificationController.onNotificationCreatedMethod,
      onNotificationDisplayedMethod:  NotificationController.onNotificationDisplayedMethod,
      onDismissActionReceivedMethod:  NotificationController.onDismissActionReceivedMethod
  );

  // --- Check and Request Permission ---
  // It's generally better to request permission later in the app flow
  // when the user understands why notifications are needed (e.g., after login
  // or when they first view the performer screen).
  // We'll add a function to call from AuthWrapper later.
  // --- End Permission Check ---

  // --- End Awesome Notifications Initialization ---

  runApp(MyApp());
}

// --- Awesome Notifications Controller (Static methods required) ---
// Place this outside any class or ensure methods are static if inside a class
class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future <void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    print('NOTIFICATION CREATED: ${receivedNotification.id}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future <void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    print('NOTIFICATION DISPLAYED: ${receivedNotification.id}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future <void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    print('NOTIFICATION DISMISSED: ${receivedAction.id}');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future <void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    print('NOTIFICATION ACTION RECEIVED: ${receivedAction.id}');
    final payload = receivedAction.payload; // Payload is a Map<String?, String?>?
    if (payload != null) {
       print('Payload: $payload');
       // TODO: Implement navigation based on payload.
       // This is tricky from a background isolate. Often requires
       // saving the target route/data and handling it when the app resumes,
       // or using a more complex setup with Navigator keys accessible globally.
       // Example concept:
       // if (payload.containsKey('listId')) {
       //   String? listId = payload['listId'];
       //   print("Navigate to list: $listId");
       //   // MyApp.navigatorKey.currentState?.pushNamed('/listDetail', arguments: listId); // If using global key
       // }
    }
  }
}
// --- End Notification Controller ---


class MyApp extends StatelessWidget {
    final Color primaryBlue = Colors.blue.shade400;
    final Color buttonBlue = Colors.blue.shade600;

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        // Optional: Add navigatorKey for potential background navigation handling
        // navigatorKey: MyApp.navigatorKey, // Define static key if needed
        title: 'Booked Mic',
        theme: ThemeData( /* ... Theme Definition ... */ ),
        home: AuthWrapper(),
        routes: { /* ... Routes ... */ },
      );
    }
    // Define static key if using for navigation from notification action
    // static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class AuthWrapper extends StatefulWidget { // Change to StatefulWidget for initState
    const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
    @override
    void initState() {
      super.initState();
      // --- Request Permission After Initial Frame ---
      // Request notification permission shortly after the AuthWrapper builds
      // (and presumably after login is confirmed). Avoids blocking main().
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _requestNotificationPermission();
      });
      // --- End Request ---
    }

    Future<void> _requestNotificationPermission() async {
       bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
       if (!isAllowed && mounted) { // Check mounted before showing dialog
          print("Requesting notification permission...");
          // Consider showing a dialog explaining why first
          // await showDialog(...);
          await AwesomeNotifications().requestPermissionToSendNotifications();
          // Re-check status after request
          isAllowed = await AwesomeNotifications().isNotificationAllowed();
          print("Permission allowed after request: $isAllowed");
       } else {
          print("Notifications already allowed or widget not mounted.");
       }
    }


    Future<String?> _getSavedRole() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    }

    @override
    Widget build(BuildContext context) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (authSnapshot.hasData && authSnapshot.data != null) {
            // User is logged in
            return FutureBuilder<String?>(
              future: _getSavedRole(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (roleSnapshot.hasError) {
                   print("Error fetching saved role: ${roleSnapshot.error}");
                   return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error loading user profile. Please try restarting the app.\n(${roleSnapshot.error})", textAlign: TextAlign.center))));
                }

                final role = roleSnapshot.data;
                if (role == 'host') return CreatedListsScreen();
                else if (role == 'performer') return PerformerListScreen();
                else return RoleSelectionScreen();
              },
            );
          } else {
            // User is not logged in
            return RegistrationScreen();
          }
        },
      );
    }
}
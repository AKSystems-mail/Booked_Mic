// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/services/settings_service.dart'; // Import new service
// --- Import Awesome Notifications ---
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:myapp/services/notification_service.dart';
import 'dart:async';

// Import your screen widgets
import 'firebase_options.dart';
import 'registration_screen.dart'; // Keep imports for routes/AuthWrapper
import 'role_selection_screen.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
     await dotenv.load(fileName: ".env");
     // print(".env file loaded successfully.");
  } catch (e) {
     // print("Error loading .env file: $e");
  }

  // --- Awesome Notifications Initialization ---
  await AwesomeNotifications().initialize(
    // Set the icon to null to use the default app icon
    'resource://drawable/res_app_icon', // Or 'resource://drawable/res_app_icon' if you have one
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

   runApp(
    MultiProvider(
      providers: [
        // Your existing FirestoreProvider
        ChangeNotifierProvider(create: (_) => FirestoreProvider()),

        // Add SettingsService (using simple Provider if no listening needed directly)
        Provider(create: (_) => SettingsService.instance), // Provide singleton instance

        // --- Add other providers as needed by specific routes ---
        // Note: TimerService and FlashlightService need listId, so they
        // should be provided closer to where ShowListScreen is used,
        // OR you need a way to manage instances per listId if multiple
        // lists can be open simultaneously.
        // Providing them directly here is problematic if they are list-specific.
        // See ShowListScreen widget above for how they are provided there instead.

        // --- Example if they were app-wide (NOT list-specific) ---
        // ChangeNotifierProvider(
        //   create: (context) => TimerService(listId: 'some_default_or_managed_id'),
        // ),
        // ChangeNotifierProxyProvider<TimerService, FlashlightService>(
        //   create: (context) => FlashlightService(
        //     listId: 'some_default_or_managed_id',
        //     timerService: Provider.of<TimerService>(context, listen: false),
        //   ),
        //   update: (context, timerService, previous) => previous!..updateDependencies(timerService),
        // ),
         // ----------------------------------------------------------
      ],
      child: MyApp(),
    ),
 );
}

// --- Awesome Notifications Controller (Static methods required) ---
// Place this outside any class or ensure methods are static if inside a class
class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future <void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future <void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future <void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future <void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    final payload = receivedAction.payload; // Payload is a Map<String?, String?>?
    if (payload != null) {
    }
  }
}
// --- End Notification Controller ---


class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error initializing Firebase: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            title: 'Booked Mic',
            theme: ThemeData( /* ... Theme Definition ... */ ),
            home: AuthWrapper(),
            routes: { /* ... Routes ... */ },
          );
        }

        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget { // Change to StatefulWidget for initState
    const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
    StreamSubscription<User?>? _authSubscription;

    @override
    void initState() {
      super.initState();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _requestNotificationPermission();
      });

      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          // User is logged in
          final role = await _getSavedRole();
          if (role == 'performer') {
            NotificationService().startListening(user.uid);
          } else {
            // If role is not performer or not set, stop listening
            NotificationService().stopListening();
          }
        } else {
          // User is logged out
          NotificationService().stopListening();
        }
      });
    }

    @override
    void dispose() {
      _authSubscription?.cancel();
      super.dispose();
    }

    Future<void> _requestNotificationPermission() async {
       bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
       if (!isAllowed && mounted) {
          await AwesomeNotifications().requestPermissionToSendNotifications();
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
            return FutureBuilder<String?>(
              future: _getSavedRole(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (roleSnapshot.hasError) {
                   return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error loading user profile. Please try restarting the app.\n(${roleSnapshot.error})", textAlign: TextAlign.center))));
                }

                final role = roleSnapshot.data;
                if (role == 'host') {
                  return CreatedListsScreen();
                } else if (role == 'performer') {
                  return PerformerListScreen();
                }
                else {
                  return RoleSelectionScreen();
                }
              },
            );
          } else {
            return RegistrationScreen();
          }
        },
      );
    }
}
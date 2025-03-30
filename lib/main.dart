// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Keep firebase_auth import as User type is used in StreamBuilder
import 'package:firebase_auth/firebase_auth.dart';
// Keep shared_preferences import as it's used in _getSavedRole
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import your screen widgets (These ARE used by AuthWrapper)
import 'firebase_options.dart';
import 'registration_screen.dart';
import 'role_selection_screen.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

  runApp(MyApp());
}

// --- Local Notification Handlers ---
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    print('Notification TAPPED - Payload: $payload');
    // TODO: Implement navigation logic based on payload if desired
  }
}

// --- Commented out unused function ---
/*
Future<void> _requestAndroidPermissions(BuildContext context) async {
  // ... function body ...
}
*/
// --- End Comment ---

class MyApp extends StatelessWidget {
    final Color primaryBlue = Colors.blue.shade400;
    final Color buttonBlue = Colors.blue.shade600;

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Booked Mic',
        theme: ThemeData( /* ... Theme Definition ... */
          primaryColor: primaryBlue,
          colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue, primary: primaryBlue, secondary: Colors.purple.shade100),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0, titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500), iconTheme: IconThemeData(color: Colors.white)),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: buttonBlue, minimumSize: Size(double.infinity, 50), padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), elevation: 5)),
          outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: buttonBlue, minimumSize: Size(double.infinity, 50), padding: EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: buttonBlue, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)), textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryBlue, width: 1.5)), labelStyle: TextStyle(color: Colors.grey.shade700), hintStyle: TextStyle(color: Colors.grey.shade500), prefixIconColor: Colors.grey.shade600),
          scaffoldBackgroundColor: Colors.purple.shade50,
          floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primaryBlue, foregroundColor: Colors.white),
        ),
        home: AuthWrapper(),
        routes: {
          // Keep routes even if imports flagged, they define navigation targets
          '/registration': (context) => RegistrationScreen(),
          '/roleSelection': (context) => RoleSelectionScreen(),
          '/hostHome': (context) => CreatedListsScreen(),
          '/performerHome': (context) => PerformerListScreen(),
        },
      );
    }
}

class AuthWrapper extends StatelessWidget {
    const AuthWrapper({Key? key}) : super(key: key);

    Future<String?> _getSavedRole() async {
      final prefs = await SharedPreferences.getInstance();
      // Optional: Add a small delay for testing loading states
      // await Future.delayed(Duration(seconds: 1));
      // Optional: Simulate an error for testing
      // throw Exception("Failed to load role");
      return prefs.getString('user_role');
    }

    @override
    Widget build(BuildContext context) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            // Show loading indicator while checking auth state
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (authSnapshot.hasData && authSnapshot.data != null) {
            // User is logged in, check for saved role
            return FutureBuilder<String?>(
              future: _getSavedRole(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  // Show loading indicator while fetching role
                  return Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                // --- *** ADDED ERROR HANDLING *** ---
                if (roleSnapshot.hasError) {
                   print("Error fetching saved role: ${roleSnapshot.error}");
                   // Show an error message or fallback screen (e.g., RoleSelection)
                   return Scaffold(
                      body: Center(
                         child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text("Error loading user profile. Please try restarting the app.\n(${roleSnapshot.error})", textAlign: TextAlign.center),
                         )
                      )
                   );
                }
                // --- *** END ERROR HANDLING *** ---

                // Proceed if future completed without error
                final role = roleSnapshot.data;
                if (role == 'host') {
                  return CreatedListsScreen();
                } else if (role == 'performer') {
                  return PerformerListScreen();
                } else {
                  // No role saved, or invalid role -> go to Role Selection
                  return RoleSelectionScreen();
                }
              },
            );
          } else {
            // User is not logged in
            return RegistrationScreen();
          }
        },
      );
    } // Added missing closing brace for build method
} // Added missing closing brace for AuthWrapper class
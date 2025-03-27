// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your screen widgets
import 'firebase_options.dart'; // Make sure this path is correct
import 'registration_screen.dart';
import 'role_selection_screen.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart'; // Assuming you have this screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booked Mic',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Example Theme
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(), // Use a wrapper to handle auth state
      // Define routes if you use named navigation
      routes: {
        '/registration': (context) => RegistrationScreen(),
        '/roleSelection': (context) => RoleSelectionScreen(),
        '/hostHome': (context) => CreatedListsScreen(),
        '/performerHome': (context) => PerformerListScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
          return Scaffold(body: Center(child: CircularProgressIndicator())); // Loading indicator
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          // User is logged in, check for saved role
          return FutureBuilder<String?>(
            future: _getSavedRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: CircularProgressIndicator())); // Loading indicator
              }

              final role = roleSnapshot.data;

              if (role == 'host') {
                return CreatedListsScreen(); // Navigate to Host screen
              } else if (role == 'performer') {
                return PerformerListScreen(); // Navigate to Performer screen
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
  }
}
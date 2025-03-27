// lib/pages/performer_list_screen.dart (Example Structure)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import necessary screens
import '../role_selection_screen.dart';
// If handling logout/redirects

class PerformerListScreen extends StatelessWidget {
  PerformerListScreen({Key? key}) : super(key: key);

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // --- Function to handle switching role (Identical to created_lists_screen) ---
  Future<void> _switchRole(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role'); // Clear the saved role

    // Navigate back to RoleSelectionScreen, replacing the current screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
    );
  }
  // --- End Function ---

  @override
  Widget build(BuildContext context) {
     if (currentUserId == null) {
       // Fallback redirect if needed
       WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/registration');
       });
       return Scaffold(body: Center(child: Text("Redirecting...")));
     }

    return Scaffold(
      appBar: AppBar(
        title: Text('Available Lists (Performer)'), // Indicate role
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        // --- Add Actions for the Button ---
        actions: [
          Tooltip(
             message: 'Switch Role',
             child: IconButton(
                icon: Icon(Icons.switch_account),
                onPressed: () => _switchRole(context), // Call the switch role function
             ),
          ),
        ],
        // --- End Actions ---
      ),
      body: Center(
        // TODO: Implement the body of the performer list screen
        // (e.g., StreamBuilder fetching lists available for signup)
        child: Text('Performer List Screen - Implement List Fetching Here'),
      ),
      // Optional: Add FAB for searching or other actions
    );
  }
}
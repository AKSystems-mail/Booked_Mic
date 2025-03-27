// lib/pages/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for potential sign out

// Import destination screens
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';
import 'registration_screen.dart'; // For sign out navigation

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);

    // Use pushReplacement to remove RoleSelectionScreen from the stack
    if (role == 'host') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CreatedListsScreen()),
      );
    } else if (role == 'performer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PerformerListScreen()),
      );
    }
  }

  // Optional: Add sign out
  Future<void> _signOut(BuildContext context) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove('user_role'); // Clear role on sign out
     await FirebaseAuth.instance.signOut();
     // Navigate back to registration after sign out, clearing the stack
     Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => RegistrationScreen()),
        (Route<dynamic> route) => false, // Remove all routes below
     );
  }


  @override
  Widget build(BuildContext context) {
    // --- Button Style Helper (copied from registration_screen for consistency) ---
    ButtonStyle _buttonStyle() {
      return ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        minimumSize: Size(double.infinity, 50),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        textStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        elevation: 5,
      );
    }
    // --- End Button Style Helper ---


    return Scaffold(
      appBar: AppBar(
        title: Text('Select Your Role'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button
         actions: [ // Optional Sign Out Button
           IconButton(
             icon: Icon(Icons.logout),
             tooltip: 'Sign Out',
             onPressed: () => _signOut(context),
           ),
         ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Choose how you want to use the app:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              SizedBox(height: 40),
              ElevatedButton.icon(
                icon: Icon(Icons.mic_external_on), // Example Icon
                label: Text('Host'),
                style: _buttonStyle(),
                onPressed: () => _selectRole(context, 'host'),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.person_search), // Example Icon
                label: Text('Performer'),
                style: _buttonStyle(),
                onPressed: () => _selectRole(context, 'performer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
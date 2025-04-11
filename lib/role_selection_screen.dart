// lib/pages/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

// Import destination screens
import 'host_screens/created_lists_screen.dart'; // Adjusted path assuming structure
import 'performer_screens/performer_list_screen.dart'; // Adjusted path assuming structure
import 'registration_screen.dart'; // For sign out navigation

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

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
    // Colors from reference style
    final Color appBarColor = Colors.blue.shade400;
    final Color buttonColor = const Color.fromARGB(255, 108, 28, 133);

    return Scaffold(
      appBar: AppBar(
        // Apply reference style
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Select Your Role'),
        automaticallyImplyLeading: false, // Keep back button removed as per previous logic
        actions: [ // Keep Sign Out Button
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _signOut(context),
            ),
          ),
        ],
      ),
      // Apply gradient background from reference
      body: Container(
        width: double.infinity, // Ensure gradient fills width
        height: double.infinity, // Ensure gradient fills height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        // Original content goes inside the gradient container
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Apply FadeInDown to introductory text
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Are you Hosting or Performing?',
                    textAlign: TextAlign.center,
                    // Style text to be visible on gradient
                    style: TextStyle(fontSize: 18, color: Colors.black.withOpacity(0.7)),
                  ),
                ),
                SizedBox(height: 40),

                // Apply FadeInDown sequentially to buttons
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50, // Adjust the size as needed
                        backgroundColor: buttonColor,
                        child: IconButton(
                          icon: Icon(
                            Icons.mic_external_on,
                            color: Colors.white,
                            size: 40, // Adjust the size as needed
                          ),
                          onPressed: () => _selectRole(context, 'host'),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Host',
                        style: TextStyle(color: buttonColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                FadeInDown(
                  duration: const Duration(milliseconds: 700),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50, // Adjust the size as needed
                        backgroundColor: buttonColor,
                        child: IconButton(
                          icon: Icon(
                            Icons.emoji_people_outlined,
                            color: Colors.white,
                            size: 40, // Adjust the size as needed
                          ),
                          onPressed: () => _selectRole(context, 'performer'),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Performer',
                        style: TextStyle(color: buttonColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

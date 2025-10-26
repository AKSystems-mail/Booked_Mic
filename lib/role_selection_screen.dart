
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

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

  Future<void> _performSignOut(BuildContext context) async {
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

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently signed in.')),
      );
      return;
    }

    // Prompt for re-authentication
    final bool? reauthenticated = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController emailController = TextEditingController(text: user.email);
        final TextEditingController passwordController = TextEditingController();
        return AlertDialog(
          title: const Text('Re-authenticate to Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your password to confirm account deletion.'),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                enabled: false, // Email should not be editable
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  Navigator.of(dialogContext).pop(true); // Re-authentication successful
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Re-authentication failed: ${e.message}')),
                  );
                  Navigator.of(dialogContext).pop(false); // Re-authentication failed
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (reauthenticated == null || !reauthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion cancelled or re-authentication failed.')),
      );
      return;
    }

    try {
      // Delete user data from Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      // TODO: Implement deletion of other user-related data (e.g., shows, signups)

      // Delete user from Firebase Authentication
      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role'); // Clear role on account deletion

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account and associated data deleted successfully.')),
      );

      // Navigate back to registration after account deletion, clearing the stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => RegistrationScreen()),
        (Route<dynamic> route) => false, // Remove all routes below
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  void _showSignOutOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext dialogContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  _performSignOut(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(dialogContext).pop(); // Close the dialog
                  _deleteAccount(context);
                },
              ),
            ],
          ),
        );
      },
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
        title: const Text('Select Your Role'),
        automaticallyImplyLeading: false, // Keep back button removed as per previous logic
        actions: [ // Keep Sign Out Button
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showSignOutOptions(context),
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
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    'Booked Mic',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.8)),
                  ),
                ),
                const SizedBox(height: 20), // Add some space
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
                const SizedBox(height: 40),

                // Apply FadeInDown sequentially to buttons
                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50, // Adjust the size as needed
                        backgroundColor: buttonColor,
                        child: IconButton(
                          icon: const Icon(
                            Icons.mic_external_on,
                            color: Colors.white,
                            size: 40, // Adjust the size as needed
                          ),
                          onPressed: () => _selectRole(context, 'host'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Host',
                        style: TextStyle(color: buttonColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                FadeInDown(
                  duration: const Duration(milliseconds: 700),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50, // Adjust the size as needed
                        backgroundColor: buttonColor,
                        child: IconButton(
                          icon: const Icon(
                            Icons.emoji_people_outlined,
                            color: Colors.white,
                            size: 40, // Adjust the size as needed
                          ),
                          onPressed: () => _selectRole(context, 'performer'),
                        ),
                      ),
                      const SizedBox(height: 10),
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


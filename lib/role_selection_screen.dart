
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';
import 'registration_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (!context.mounted) return;

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
    await prefs.remove('last_known_uid'); // Clear cached UID
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    // Navigate back to registration after sign out, clearing the stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => RegistrationScreen()),
      (Route<dynamic> route) => false, // Remove all routes below
    );
  }

  Future<bool?> _reauthenticateWithEmail(User user, BuildContext context) async {
    return showDialog<bool>(
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
                enabled: false,
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
                  Navigator.of(dialogContext).pop(true);
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Re-authentication failed: ${e.message}')),
                  );
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _reauthenticateWithGoogle(User user) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return false;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Google re-auth failed: $e');
      return false;
    }
  }

  Future<bool> _reauthenticateWithApple(User user) async {
    if (kIsWeb) return false;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final OAuthCredential authCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      await user.reauthenticateWithCredential(authCredential);
      return true;
    } catch (e) {
      debugPrint('Apple re-auth failed: $e');
      return false;
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently signed in.')),
      );
      return;
    }

    final providers = user.providerData.map((info) => info.providerId).toSet();

    bool reauthenticated = false;
    if (providers.contains('password')) {
      final result = await _reauthenticateWithEmail(user, context);
      reauthenticated = result == true;
    } else if (providers.contains('google.com')) {
      reauthenticated = await _reauthenticateWithGoogle(user);
    } else if (providers.contains('apple.com')) {
      reauthenticated = await _reauthenticateWithApple(user);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No supported sign-in method found for re-authentication.')),
      );
      return;
    }

    if (!reauthenticated) {
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
      await prefs.remove('last_known_uid'); // Clear cached UID

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
    final Color hostButtonColor = Colors.purple.shade800;
    final Color performerButtonColor = Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Booked Mic',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showSignOutOptions(context),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade200, Colors.purple.shade100],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Welcome! Choose your role:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 50),

                FadeInDown(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _selectRole(context, 'host'),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: hostButtonColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mic_external_on, color: Colors.white, size: 50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Host',
                        style: TextStyle(color: hostButtonColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                FadeInDown(
                  duration: const Duration(milliseconds: 700),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _selectRole(context, 'performer'),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: performerButtonColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_search, color: Colors.white, size: 50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Performer',
                        style: TextStyle(color: performerButtonColor, fontSize: 18, fontWeight: FontWeight.bold),
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


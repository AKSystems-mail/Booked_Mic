// lib/pages/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed to save user data

// Import the screen to navigate to after successful login/signup
import 'role_selection_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // --- State Variables ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Add Stage Name controller
  final _stageNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // --- Lifecycle Methods ---
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _stageNameController.dispose(); // Dispose stage name controller
    super.dispose();
  }

  // --- Navigation ---
  void _navigateToNextScreen() {
     if (mounted) {
        Navigator.pushReplacement(
           context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        );
     }
  }

  // --- Authentication Logic ---

  // Combined Sign In / Sign Up Logic for Email Button
  Future<void> _signInOrSignUpWithEmailAndPassword() async {
    FocusScope.of(context).unfocus();
    // Include validation for stage name if creating account
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    // Get stage name here, it will be used if creating account
    final String stageName = _stageNameController.text.trim();

    try {
      // Attempt to sign in first
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User signed in: ${userCredential.user?.uid}");
      // Optional: Could check/update stage name in Firestore on sign-in if needed
      if (mounted && userCredential.user != null) {
         _navigateToNextScreen();
      }
    } on FirebaseAuthException catch (e) {
      print("Sign-in failed: ${e.code}");
      // If user not found or invalid credential, try creating account
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        print("User not found, attempting to create account...");
        // Pass stage name to creation method
        await _createUserWithEmailAndPassword(email, password, stageName);
      } else {
        // Handle other sign-in errors
        String message;
        switch (e.code) { /* ... error handling ... */
           case 'wrong-password': message = 'Incorrect password provided.'; break;
           case 'invalid-email': message = 'The email address format is not valid.'; break;
           case 'user-disabled': message = 'This user account has been disabled.'; break;
           case 'too-many-requests': message = 'Too many attempts. Please try again later.'; break;
           case 'network-request-failed': message = 'Network error. Please check your connection.'; break;
           default: message = 'Login failed. Please try again.';
        }
        if (mounted) setState(() { _errorMessage = message; _isLoading = false; });
      }
    } catch (e) {
       print("General Error during Sign In attempt: $e");
       if (mounted) setState(() { _errorMessage = 'An unexpected error occurred.'; _isLoading = false; });
    }
  }

  // Helper method to create user - now accepts stageName
  Future<void> _createUserWithEmailAndPassword(String email, String password, String stageName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User created: ${userCredential.user?.uid}");

      // Save user data to Firestore, including stageName
      if (userCredential.user != null) {
         await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email,
            'stageName': stageName, // Save the provided stage name
            'createdAt': FieldValue.serverTimestamp(),
         });
         print("User data saved to Firestore.");
      }

      if (mounted && userCredential.user != null) {
         _navigateToNextScreen();
      }
    } on FirebaseAuthException catch (e) {
      print("Account Creation failed: ${e.code}");
      String message;
      switch (e.code) { /* ... error handling ... */
         case 'email-already-in-use': message = 'This email is already registered. Try signing in.'; break;
         case 'weak-password': message = 'The password is too weak.'; break;
         case 'invalid-email': message = 'The email address format is not valid.'; break;
         case 'network-request-failed': message = 'Network error. Please check your connection.'; break;
         default: message = 'Account creation failed. Please try again.';
      }
      if (mounted) setState(() { _errorMessage = message; });
    } catch (e) {
       print("General Error during Account Creation: $e");
       if (mounted) setState(() { _errorMessage = 'An unexpected error occurred.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }


  // Google Sign In
  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false); return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Save/Update user data on Google Sign In
      if (userCredential.user != null) {
         final userRef = _firestore.collection('users').doc(userCredential.user!.uid);
         final userSnap = await userRef.get();

         // Prepare data - use Google display name as default stage name if creating new doc
         Map<String, dynamic> userData = {
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email,
            'photoURL': userCredential.user!.photoURL, // Save photo URL
            // Set stageName only if user doc doesn't exist OR if stageName field is missing
            if (!userSnap.exists || (userSnap.exists && !(userSnap.data() as Map).containsKey('stageName')))
               'stageName': userCredential.user!.displayName ?? userCredential.user!.email?.split('@')[0], // Google name or default
            if (!userSnap.exists) // Set createdAt only for new users
               'createdAt': FieldValue.serverTimestamp(),
         };

         // Use set with merge to add/update data without overwriting existing fields unnecessarily
         await userRef.set(userData, SetOptions(merge: true));
         print("Google user data saved/updated in Firestore.");
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen();
    } on FirebaseAuthException catch (e) { /* ... error handling ... */
      print("Firebase Auth Error (Google): ${e.code} - ${e.message}");
       if (mounted) {
          setState(() {
             if (e.code == 'account-exists-with-different-credential') {
               _errorMessage = 'An account already exists with the same email address using a different sign-in method.';
             } else if (e.code == 'network-request-failed') {
                _errorMessage = 'Network error. Please check your connection.';
             } else { _errorMessage = 'Google Sign-In failed. Please try again.'; }
          });
       }
    } catch (e) { /* ... error handling ... */
      print("General Error during Google Sign In: $e");
       if (mounted) setState(() { _errorMessage = 'An unexpected error occurred during Google Sign-In.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  // --- End Authentication Logic ---


  // --- UI Styling Helpers --- (remain the same)
  ButtonStyle _elevatedButtonStyle() { /* ... */
     return ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Theme.of(context).primaryColor, minimumSize: Size(double.infinity, 50), padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)), textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), elevation: 5);
  }
  // No longer need _outlinedButtonStyle
  // ButtonStyle _outlinedButtonStyle() { /* ... */ }
  // --- End UI Styling Helpers ---


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Title
                  Text('Booked Mic', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor)),
                  SizedBox(height: 40),

                  // Email Field (remains the same)
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email', hintText: 'Enter your email', prefixIcon: Icon(Icons.email_outlined, color: primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: primaryColor, width: 2.0))),
                    keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                    validator: (value) { if (value == null || value.trim().isEmpty) return 'Please enter your email'; if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return 'Please enter a valid email address'; return null; },
                  ),
                  SizedBox(height: 16),

                  // Password Field (remains the same)
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Password', hintText: 'Enter your password', prefixIcon: Icon(Icons.lock_outline, color: primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: primaryColor, width: 2.0))),
                    obscureText: true, textInputAction: TextInputAction.next, // Change to next
                    validator: (value) { if (value == null || value.isEmpty) return 'Please enter your password'; if (value.length < 6) return 'Password must be at least 6 characters'; return null; }, // Added length validation
                  ),
                  SizedBox(height: 16), // Add spacing

                  // --- Stage Name Field ---
                  TextFormField(
                    controller: _stageNameController,
                    decoration: InputDecoration(
                      labelText: 'Stage Name',
                      hintText: 'Enter your stage name',
                      prefixIcon: Icon(Icons.mic_external_on_outlined, color: primaryColor), // Icon for stage name
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(8.0),
                         borderSide: BorderSide(color: primaryColor, width: 2.0),
                      ),
                    ),
                    textInputAction: TextInputAction.done, // Last field
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your stage name';
                      }
                      return null;
                    },
                    // Use the combined sign-in/sign-up method on submit
                    onFieldSubmitted: (_) { if (!_isLoading) _signInOrSignUpWithEmailAndPassword(); },
                  ),
                  // --- End Stage Name Field ---

                  SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 14), textAlign: TextAlign.center)),

                  // Loading Indicator or Buttons
                  _isLoading
                  ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(color: primaryColor)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Sign In / Sign Up Button
                        ElevatedButton.icon(
                          icon: Icon(Icons.login),
                          label: Text('Sign In / Sign Up'),
                          style: _elevatedButtonStyle(),
                          onPressed: _signInOrSignUpWithEmailAndPassword,
                        ),
                        SizedBox(height: 12),
                        // Google Sign In Button
                        ElevatedButton.icon(
                          icon: Icon(Icons.g_mobiledata_outlined, size: 28), label: Text('Sign In with Google'),
                          style: _elevatedButtonStyle(), onPressed: _signInWithGoogle,
                        ),
                        // Removed Divider and Create Account Button
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
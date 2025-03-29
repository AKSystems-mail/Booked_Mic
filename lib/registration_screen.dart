// lib/pages/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do

// Import the screen to navigate to after successful login/signup
import 'role_selection_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // --- State Variables ---
  // These ARE used by the restored functions below
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stageNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // --- Lifecycle Methods ---
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _stageNameController.dispose();
    super.dispose();
  }

  // --- Navigation ---
  // This IS used by the restored functions below
  void _navigateToNextScreen() {
     if (mounted) {
        Navigator.pushReplacement(
           context, MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        );
     }
  }

  // --- *** RESTORED AUTHENTICATION LOGIC *** ---

  // Combined Sign In / Sign Up Logic for Email Button
  Future<void> _signInOrSignUpWithEmailAndPassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String stageName = _stageNameController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User signed in: ${userCredential.user?.uid}");
      if (mounted && userCredential.user != null) {
         _navigateToNextScreen(); // Navigate on success
      }
    } on FirebaseAuthException catch (e) {
      print("Sign-in failed: ${e.code}");
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        print("User not found, attempting to create account...");
        // Pass stage name to creation method
        await _createUserWithEmailAndPassword(email, password, stageName); // Call creation helper
      } else {
        String message;
        switch (e.code) {
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
    // isLoading state for signup is handled within _createUserWithEmailAndPassword's finally block
  }

  // Helper method to create user - This IS used by _signInOrSignUpWithEmailAndPassword
  Future<void> _createUserWithEmailAndPassword(String email, String password, String stageName) async {
    // No need to set isLoading = true here, it's already true from the calling function
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("User created: ${userCredential.user?.uid}");

      if (userCredential.user != null) {
         await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'email': email,
            'stageName': stageName,
            'createdAt': FieldValue.serverTimestamp(),
         });
         print("User data saved to Firestore.");
      }

      if (mounted && userCredential.user != null) {
         _navigateToNextScreen(); // Navigate on success
      }
    } on FirebaseAuthException catch (e) {
      print("Account Creation failed: ${e.code}");
      String message;
      switch (e.code) {
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
      // Ensure loading indicator stops *after* creation attempt finishes
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

      if (userCredential.user != null) {
         final userRef = _firestore.collection('users').doc(userCredential.user!.uid);
         final userSnap = await userRef.get();
         Map<String, dynamic> userData = {
            'uid': userCredential.user!.uid, 'email': userCredential.user!.email,
            'photoURL': userCredential.user!.photoURL,
            if (!userSnap.exists || (userSnap.exists && !(userSnap.data() as Map).containsKey('stageName')))
               'stageName': userCredential.user!.displayName ?? userCredential.user!.email?.split('@')[0],
            if (!userSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
         };
         await userRef.set(userData, SetOptions(merge: true));
         print("Google user data saved/updated in Firestore.");
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen(); // Navigate on success
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error (Google): ${e.code} - ${e.message}");
       if (mounted) {
          setState(() {
             if (e.code == 'account-exists-with-different-credential') { _errorMessage = 'An account already exists with the same email address using a different sign-in method.'; }
             else if (e.code == 'network-request-failed') { _errorMessage = 'Network error. Please check your connection.'; }
             else { _errorMessage = 'Google Sign-In failed. Please try again.'; }
          });
       }
    } catch (e) {
      print("General Error during Google Sign In: $e");
       if (mounted) setState(() { _errorMessage = 'An unexpected error occurred during Google Sign-In.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  // --- *** END RESTORED AUTHENTICATION LOGIC *** ---


  // --- UI Styling Helper ---
  ButtonStyle _elevatedButtonStyle() {
    final Color buttonColor = Colors.blue.shade600;
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white, backgroundColor: buttonColor,
      minimumSize: Size(double.infinity, 50), padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), elevation: 5,
    );
  }
  // --- End UI Styling Helper ---


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color buttonColor = Colors.blue.shade600;

    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.blue.shade200, Colors.purple.shade100]),
        ),
        child: SafeArea(
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
                    FadeInDown(duration: const Duration(milliseconds: 400), child: Text('Booked Mic', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
                    SizedBox(height: 40),

                    // Email Field
                    FadeInDown(duration: const Duration(milliseconds: 500), child: TextFormField(controller: _emailController, decoration: InputDecoration(labelText: 'Email', hintText: 'Enter your email', prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade700), filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5))), keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: (value) { if (value == null || value.trim().isEmpty) return 'Please enter your email'; if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) return 'Please enter a valid email address'; return null; })),
                    SizedBox(height: 16),

                    // Password Field
                    FadeInDown(duration: const Duration(milliseconds: 600), child: TextFormField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password', hintText: 'Enter your password', prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade700), filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5))), obscureText: true, textInputAction: TextInputAction.next, validator: (value) { if (value == null || value.isEmpty) return 'Please enter your password'; if (value.length < 6) return 'Password must be at least 6 characters'; return null; })),
                    SizedBox(height: 16),

                    // Stage Name Field
                    FadeInDown(duration: const Duration(milliseconds: 700), child: TextFormField(controller: _stageNameController, decoration: InputDecoration(labelText: 'Stage Name', hintText: 'Enter your stage name', prefixIcon: Icon(Icons.mic_external_on_outlined, color: Colors.grey.shade700), filled: true, fillColor: Colors.white.withOpacity(0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5))), textInputAction: TextInputAction.done, validator: (value) { if (value == null || value.trim().isEmpty) return 'Please enter your stage name'; return null; }, onFieldSubmitted: (_) { if (!_isLoading) _signInOrSignUpWithEmailAndPassword(); })),
                    SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null) Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),

                    // Loading Indicator or Buttons
                    _isLoading
                    ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(color: buttonColor)))
                    : ElasticIn(
                        duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Sign In / Sign Up Button
                            ElevatedButton.icon(icon: Icon(Icons.login), label: Text('Sign In / Sign Up'), style: _elevatedButtonStyle(), onPressed: _signInOrSignUpWithEmailAndPassword), // Ensure this calls the function
                            SizedBox(height: 12),
                            // Google Sign In Button
                            ElevatedButton.icon(icon: Icon(Icons.g_mobiledata_outlined, size: 28), label: Text('Sign In with Google'), style: _elevatedButtonStyle(), onPressed: _signInWithGoogle), // Ensure this calls the function
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
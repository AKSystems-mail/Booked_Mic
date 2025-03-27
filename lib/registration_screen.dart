// lib/pages/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Import the screen to navigate to after successful login
import 'role_selection_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage; // To display login errors

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Authentication Logic ---

  Future<void> _signInWithEmailAndPassword() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Navigate on success
      if (mounted && userCredential.user != null) {
        _navigateToNextScreen();
      }

    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error (Email): ${e.code} - ${e.message}"); // Log detailed error
      String message;
      // Provide more user-friendly messages
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential': // Covers both wrong email/password in newer SDKs
           message = 'Incorrect email or password. Please try again.';
           break;
        case 'wrong-password': // Might still occur in some cases
          message = 'Incorrect password provided.';
          break;
        case 'invalid-email':
          message = 'The email address format is not valid.';
          break;
        case 'user-disabled':
           message = 'This user account has been disabled.';
           break;
        case 'too-many-requests':
           message = 'Too many login attempts. Please try again later.';
           break;
        case 'network-request-failed':
           message = 'Network error. Please check your connection.';
           break;
        default:
          message = 'Login failed. Please try again.'; // Generic fallback
      }
       if (mounted) {
          setState(() {
             _errorMessage = message;
          });
       }
    } catch (e) {
       print("General Error during Email Sign In: $e");
       if (mounted) {
          setState(() {
             // Avoid showing generic technical errors directly to the user
             _errorMessage = 'An unexpected error occurred. Please try again.';
          });
       }
    } finally {
      // Ensure loading indicator stops even if widget is disposed during async operation
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Hide keyboard if open
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Trigger the Google Authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user canceled the sign-in
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential.
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Navigate on success
      if (mounted && userCredential.user != null) {
         _navigateToNextScreen();
      }

    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error (Google): ${e.code} - ${e.message}");
       if (mounted) {
          setState(() {
             // Provide a user-friendly message
             if (e.code == 'account-exists-with-different-credential') {
               _errorMessage = 'An account already exists with the same email address using a different sign-in method.';
             } else if (e.code == 'network-request-failed') {
                _errorMessage = 'Network error. Please check your connection.';
             }
             else {
               _errorMessage = 'Google Sign-In failed. Please try again.';
             }
          });
       }
    } catch (e) {
      print("General Error during Google Sign In: $e");
       if (mounted) {
          setState(() {
             _errorMessage = 'An unexpected error occurred during Google Sign-In.';
          });
       }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToNextScreen() {
     // After successful login, ALWAYS go to RoleSelectionScreen initially.
     // The AuthWrapper (in main.dart) will handle skipping this on subsequent launches.
     if (mounted) {
        Navigator.pushReplacement(
           context,
           MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
        );
     }
  }

  // --- UI Styling Helper ---

  ButtonStyle _buttonStyle() {
    // Mimic the style from RoleSelectionScreen (adjust as needed)
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white, // Text color
      backgroundColor: Theme.of(context).primaryColor, // Button background color
      minimumSize: Size(double.infinity, 50), // Make buttons wide
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0), // Rounded corners
      ),
      textStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      elevation: 5, // Add some shadow
      // splashFactory: InkRipple.splashFactory, // Optional ripple effect
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // Ensure content doesn't overlap status bar/notches
        child: Center(
          child: SingleChildScrollView( // Allows scrolling if content overflows
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
                children: <Widget>[
                  // --- Logo or Title ---
                  Text(
                    'Booked Mic', // Your app name
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36, // Slightly larger title
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 40), // Increased spacing

                  // --- Email Field ---
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined), // Use outlined icons
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true, // Add subtle background fill
                      fillColor: Colors.grey[100],
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next, // Move focus to password field
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email format check
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                         return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icon(Icons.lock_outline), // Use outlined icons
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[100],
                      // TODO: Add suffix icon to toggle password visibility if desired
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done, // Action for the last field
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    // Submit form when 'done' is pressed on keyboard
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                         _signInWithEmailAndPassword();
                      }
                    },
                  ),
                  SizedBox(height: 24),

                  // --- Error Message Display ---
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // --- Loading Indicator or Buttons ---
                  _isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: CircularProgressIndicator(),
                      )
                    )
                  : Column( // Use a Column to group buttons when not loading
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Email Sign In Button ---
                        ElevatedButton.icon(
                          icon: Icon(Icons.login),
                          label: Text('Sign In with Email'),
                          style: _buttonStyle(),
                          onPressed: _signInWithEmailAndPassword,
                        ),
                        SizedBox(height: 12),

                        // --- Google Sign In Button ---
                        ElevatedButton.icon(
                          // Consider using a Google logo asset here
                          icon: Icon(Icons.g_mobiledata_outlined, size: 28), // Placeholder icon
                          label: Text('Sign In with Google'),
                          style: _buttonStyle().copyWith(
                             // Optional: Different style for Google button
                             // backgroundColor: MaterialStateProperty.all(Colors.white),
                             // foregroundColor: MaterialStateProperty.all(Colors.black87),
                          ),
                          onPressed: _signInWithGoogle,
                        ),
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
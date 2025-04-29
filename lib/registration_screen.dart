// lib/pages/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Keep for mobile
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb; // Keep for platform checks

// Import the screen to navigate to after successful login/signup
import 'role_selection_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // clientId for web preview (ensure value is correct and restricted in Cloud Console)
    clientId: kIsWeb
        ? '1049808440381-5urihcc0q51vcqt1h4ikgg3acp64tdrs.apps.googleusercontent.com'
        : null,
    // scopes: ['email'], // Request specific scopes if needed
  );

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stageNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  @mustCallSuper
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _stageNameController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    // Add mounted check before navigation
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
      );
    }
  }

  // Combined Email Sign In / Sign Up Logic
  Future<void> _signInOrSignUpWithEmailAndPassword() async {
    if (!mounted) return; // Check mounted before accessing context
    FocusScope.of(context).unfocus();

    // --- Validate Form ---
    // Use null check on currentState before calling validate
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
       print("Form validation failed."); // Debug log
       return; // Don't proceed if form is invalid
    }
    // --- End Validate ---

    setState(() { _isLoading = true; _errorMessage = null; });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String stageName = _stageNameController.text.trim(); // Stage name is required by validator

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Sign in successful, check/update stage name if needed (optional)
      if (userCredential.user != null) {
      }

      if (mounted && userCredential.user != null) {
        _navigateToNextScreen();
      }
    } on FirebaseAuthException catch (e) {
      // print("Sign-in failed: ${e.code}"); // Commented out
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {

        await _createUserWithEmailAndPassword(email, password, stageName);
      } else {
        // Handle other sign-in errors
        String message;
        switch (e.code) {
          case 'wrong-password':
            message = 'Incorrect password provided.';
            break; // Might be covered by invalid-credential
          case 'invalid-email':
            message = 'The email address format is not valid.';
            break;
          case 'user-disabled':
            message = 'This user account has been disabled.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Please try again later.';
            break;
          case 'network-request-failed':
            message = 'Network error. Please check your connection.';
            break;
          default:
            message =
                'Login failed. Please try again. (${e.code})'; // Include code for debugging
        }
        if (mounted) {
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // print("General Error during Sign In attempt: $e"); // Commented out
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
          _isLoading = false;
        });
      }
    }
    // isLoading state for signup is handled within _createUserWithEmailAndPassword's finally block
  }

  // Helper method to create user
  Future<void> _createUserWithEmailAndPassword(
      String email, String password, String stageName) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'stageName': stageName, // Use validated stage name
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted && userCredential.user != null) {
        _navigateToNextScreen();
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Try signing in.';
          break;
        case 'weak-password':
          message = 'The password is too weak (min 6 characters).';
          break;
        case 'invalid-email':
          message = 'The email address format is not valid.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Account creation failed. Please try again. (${e.code})';
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
      }
    } catch (e) {
      // print("General Error during Account Creation: $e"); // Commented out
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
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

  // Google Sign In (Mobile Flow - Refined Firestore Logic)
  Future<void> _signInWithGoogle() async {
    if (kIsWeb) {
      setState(() =>
          _errorMessage = "Google Sign-In button not active in web preview.");
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    // Get Stage Name BEFORE starting async
    final String enteredStageName = _stageNameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    GoogleSignInAccount? googleUser;
    GoogleSignInAuthentication? googleAuth;

    try {
      googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      } // User cancelled

      googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw FirebaseAuthException(code: 'google-sign-in-token-error');
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      if (!mounted) return;
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Save/Update User Data in Firestore
      if (userCredential.user != null) {
        final userRef =
            _firestore.collection('users').doc(userCredential.user!.uid);
        final userSnap = await userRef
            .get(); // userSnap is DocumentSnapshot<Map<String, dynamic>>
        final bool userExists = userSnap.exists;
// Remove the unnecessary cast here
        final Map<String, dynamic> existingData = userSnap.data() ?? {};

        // Determine the stage name to save
        String stageNameToSave;
        if (enteredStageName.isNotEmpty) {
          stageNameToSave = enteredStageName; // Prioritize entered name
        } else if (userExists &&
            existingData.containsKey('stageName') &&
            existingData['stageName'] != null &&
            existingData['stageName'].isNotEmpty) {
          stageNameToSave =
              existingData['stageName']; // Keep existing if field empty
        } else {
          stageNameToSave = userCredential.user!.displayName ??
              userCredential.user!.email?.split('@')[0] ??
              'Performer'; // Fallback
        }

        Map<String, dynamic> userData = {
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'photoURL': userCredential.user!.photoURL,
          'stageName': stageNameToSave,
          if (!userExists) 'createdAt': FieldValue.serverTimestamp(),
        };
        await userRef.set(userData, SetOptions(merge: true));
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen();
    } on FirebaseAuthException {
      if (mounted) {
        setState(() {/* ... Error message handling ... */});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred during Google Sign-In.';
        });
      }
      if (googleUser != null) {
        await _googleSignIn
            .signOut(); // Sign out Google if Firebase fails    } finally {
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- End Google Sign In ---

  // --- UI Styling Helper ---
  ButtonStyle _elevatedButtonStyle() {
    final Color buttonColor = Colors.blue.shade600;
    return ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: buttonColor,
      minimumSize: Size(double.infinity, 50),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      elevation: 5,
    );
  }
  // --- End UI Styling Helper ---

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade800;

    return Scaffold(
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
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        'Booked Mic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // Email Field
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: labelColor),
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Colors.grey.shade700),
                          filled: true,
                          fillColor: Colors.white.withAlpha((204).round()),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 16),

                    // Password Field
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: labelColor),
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Colors.grey.shade700),
                          filled: true,
                          fillColor: Colors.white.withAlpha((204).round()),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: 16),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Loading Indicator or Buttons
                    _isLoading
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child:
                                  CircularProgressIndicator(color: buttonColor),
                            ),
                          )
                        : ElasticIn(
                            duration: const Duration(milliseconds: 800),
                            delay: const Duration(milliseconds: 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email Sign In / Sign Up Button
                                ElevatedButton.icon(
                                  icon: Icon(Icons.login),
                                  label: Text('Sign In / Sign Up with Email'),
                                  style: _elevatedButtonStyle(),
                                  onPressed:
                                      _signInOrSignUpWithEmailAndPassword,
                                ),
                                SizedBox(height: 12),
                                // Google Sign In Button (Conditional for Mobile)
                                if (!kIsWeb)
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.g_mobiledata_outlined,
                                        size: 28),
                                    label: Text('Sign In with Google'),
                                    style: _elevatedButtonStyle(),
                                    onPressed: _signInWithGoogle,
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12.0),
                                    child: Text(
                                      "(Google Sign-In via button disabled in web preview)",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                    // Instructional Text
                    FadeInDown(
                      delay: Duration(milliseconds: 750),
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        "Enter Stage Name (required for Email Sign Up). If left blank for Google Sign In, your Google name will be used.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    SizedBox(height: 15),

                    // Stage Name Field
                    FadeInDown(
                      duration: const Duration(milliseconds: 700),
                      child: TextFormField(
                        controller: _stageNameController,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Stage Name',
                          labelStyle: TextStyle(color: labelColor),
                          hintText: 'How you appear on lists',
                          hintStyle: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.mic_external_on_outlined,
                              color: Colors.grey.shade700),
                          filled: true,
                          fillColor: Colors.white.withAlpha((204).round()),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (_formKey.currentState != null &&
                              _formKey.currentState!.validate() &&
                              (value == null || value.trim().isEmpty)) {}
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _signInOrSignUpWithEmailAndPassword();
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 15),
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

// lib/registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Make static so it survives widget rebuilds and doesn't re-initialize the JS SDK
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '1049808440381-5urihcc0q51vcqt1h4ikgg3acp64tdrs.apps.googleusercontent.com'
        : null,
  );

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stageNameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _showStageNameField = false;
  bool _stageNameRevealedManually = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill stage name from cached prefs if available for faster signup
    SharedPreferences.getInstance().then((prefs) {
      final cached = prefs.getString('stage_name');
      if (cached != null && cached.isNotEmpty) {
        _stageNameController.text = cached;
      }
    }).catchError((_) {});
  }

  @override
  @mustCallSuper
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _stageNameController.dispose();
    super.dispose();
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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

      final UserCredential userCredential = await _auth.signInWithCredential(authCredential);
      final User? user = userCredential.user;

      if (user != null) {
        // Check if user already has a profile in Firestore
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // New user, save profile with Apple full name if available
          String stageName = 'New Performer';
          if (credential.givenName != null || credential.familyName != null) {
            stageName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
          }
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'stageName': stageName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        _navigateToNextScreen();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Apple Sign-In failed. Please try again.';
          _isLoading = false;
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
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
      );
    }
  }

  // Combined Email Sign In / Sign Up Logic
  Future<void> _handleEmailAuth() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String stageName = _stageNameController.text.trim();

    if (_isSignUpMode) {
      // Sign-up path: validate stage name then create account
      if (stageName.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'A stage name is required to create a new account.';
            _isLoading = false;
          });
        }
        return;
      }
      await _createUserWithEmailAndPassword(email, password, stageName);
      return;
    }

    // Sign-in path
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null && stageName.isNotEmpty) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'stageName': stageName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen();

    } on FirebaseAuthException catch (e) {
      bool userNotFound = e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS';

      if (userNotFound) {
        if (mounted) {
          setState(() {
            _isSignUpMode = true;
            _showStageNameField = true;
            _isLoading = false;
            _errorMessage = 'Account not found. Enter a stage name to create a new account.';
          });
        }
      } else {
        String message = e.message ?? 'Authentication failed.';
        if (mounted) setState(() { _errorMessage = message; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'An unexpected error occurred.'; _isLoading = false; });
    }
  }

  // Helper method to create user
  Future<void> _createUserWithEmailAndPassword(
      String email, String password, String stageName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email.toLowerCase(),
          'stageName': stageName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _errorMessage = e.message ?? 'Account creation failed.'; });
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
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userRef = _firestore.collection('users').doc(userCredential.user!.uid);
        final userSnap = await userRef.get();
        
        // Only set stage name if it doesn't exist
        if (!userSnap.exists || !((userSnap.data() as Map).containsKey('stageName'))) {
          await userRef.set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email,
            'stageName': userCredential.user!.displayName ?? userCredential.user!.email?.split('@')[0] ?? 'Comedian',
            if (!userSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (mounted && userCredential.user != null) _navigateToNextScreen();
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Google Sign-In failed.'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final Color primaryColor = Theme.of(context).primaryColor;
    final Color buttonColor = Colors.blue.shade600;
    final Color labelColor = Colors.grey.shade700;

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
                  children: [
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
                    const SizedBox(height: 40),

                    // Email Field
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: labelColor),
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined, color: labelColor),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter your email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: labelColor),
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock_outline, color: labelColor),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your password';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                    ),

                    // Stage Name Field (shown in sign-up mode or when manually revealed)
                    if (_isSignUpMode || _showStageNameField)
                      FadeInDown(
                        duration: const Duration(milliseconds: 700),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextFormField(
                            controller: _stageNameController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Stage Name',
                              labelStyle: TextStyle(color: labelColor),
                              hintText: 'Enter your stage name',
                              prefixIcon: Icon(Icons.mic_external_on_outlined, color: labelColor),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleEmailAuth(),
                          ),
                        ),
                      ),

                    // Subtle link to reveal stage name field for returning users
                    if (!_isSignUpMode && !_showStageNameField)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _showStageNameField = true;
                              _stageNameRevealedManually = true;
                            });
                          },
                          child: Text(
                            "Change or Set Stage Name",
                            style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 14), textAlign: TextAlign.center),
                      ),

                    // Buttons
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(_isSignUpMode ? Icons.person_add : (_stageNameRevealedManually ? Icons.edit : Icons.login)),
                                label: Text(_isSignUpMode
                                    ? 'Create Account'
                                    : _stageNameRevealedManually
                                        ? 'Sign In & Update Name'
                                        : 'Sign In'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _handleEmailAuth,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.g_mobiledata_outlined, size: 28),
                                label: const Text('Sign In with Google'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _signInWithGoogle,
                              ),
                              if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SignInWithAppleButton(
                                    onPressed: _handleAppleSignIn,
                                    height: 50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Toggle between Sign In and Sign Up mode
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignUpMode = !_isSignUpMode;
                                    _errorMessage = null;
                                    if (!_isSignUpMode && !_stageNameRevealedManually) {
                                      _showStageNameField = false;
                                    }
                                    if (_isSignUpMode) {
                                      _showStageNameField = true;
                                    }
                                  });
                                },
                                child: Text(
                                  _isSignUpMode
                                      ? 'Already have an account? Sign In'
                                      : 'New to Booked Mic? Sign Up Here',
                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 14),
                                ),
                              ),
                            ],
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

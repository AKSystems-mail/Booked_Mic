// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
// --- Import torch_light ---
import 'package:torch_light/torch_light.dart';
// --- End Import ---
import 'package:shared_preferences/shared_preferences.dart';

// Define SpotType enum if not already globally available
enum SpotType { regular, waitlist, bucket }

class ShowListScreen extends StatefulWidget {
  final String listId;
  const ShowListScreen({Key? key, required this.listId}) : super(key: key);

  @override
  _ShowListScreenState createState() => _ShowListScreenState();
}

class _ShowListScreenState extends State<ShowListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // --- REMOVED TorchController instance ---
  // final TorchController _torchController = TorchController();

  // --- Timer State ---
  Timer? _timer;
  int _totalSeconds = 300;
  late final ValueNotifier<int> _remainingSecondsNotifier;
  int _lightThresholdSeconds = 30;
  bool _isTimerRunning = false;
  // Keep tracking flashlight state locally
  bool _isFlashlightOn = false;

  // --- Settings State ---
  bool _autoLightEnabled = false;

  @override
  void initState() {
    super.initState();
    _remainingSecondsNotifier = ValueNotifier(_totalSeconds);
    _loadSettings();
    // --- REMOVED isTorchActive check ---
    // Cannot check initial state easily with torch_light, assume off
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingSecondsNotifier.dispose();
    // --- Ensure flashlight is turned off when screen is disposed ---
    _turnFlashlightOff(); // Attempt to turn off just in case
    // --- End Ensure ---
    super.dispose();
  }

  // --- Settings Loading --- (remains the same)
  Future<void> _loadSettings() async { /* ... */ }

  // --- Save Settings --- (remains the same)
  Future<void> _saveTimerSettings() async { /* ... */ }

  // --- Timer Logic --- (remains the same)
  void _startTimer() { /* ... */ }
  void _pauseTimer() { /* ... */ }
  void _resetTimerDisplay() { /* ... */ }
  void _resetAndStopTimer() { /* ... */ }
  void _setTotalTimerDialog() async { /* ... */ }
  void _setThresholdDialog() async { /* ... */ }
  String _formatDuration(int totalSeconds) { /* ... */ }
  // --- End Timer Logic ---


  // --- Updated Light Logic using torch_light ---
  void _handleThresholdReached() {
    if (!mounted) return;
    if (_autoLightEnabled) {
      if (!_isFlashlightOn) {
         print("Auto-light enabled, turning flashlight ON.");
         _turnFlashlightOn(); // Call new function
      } else {
         print("Auto-light enabled, but flashlight already ON.");
      }
    } else {
      print("Auto-light disabled, showing prompt.");
      _showLightPrompt();
    }
  }

  Future<void> _showLightPrompt() async {
    if (!_isTimerRunning || !mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) { /* ... Dialog definition ... */ }
    );
    if (confirm == true) {
      print("Host chose 'Yes' to light prompt.");
      if (!_isFlashlightOn) {
         _turnFlashlightOn(); // Call new function
      } else {
         print("Flashlight already ON when prompt confirmed.");
      }
    } else { print("Host chose 'No' to light prompt."); }
  }

  // Explicit ON function using torch_light
  Future<void> _turnFlashlightOn() async {
    try {
      // Check availability first
      final bool isTorchAvailable = await TorchLight.isTorchAvailable();
      if (!isTorchAvailable) {
         _handleTorchError("Flashlight not available on this device.");
         return;
      }
      // Enable torch
      await TorchLight.enableTorch();
      if (mounted) setState(() => _isFlashlightOn = true);
      print("Flashlight turned ON.");
    } on EnableTorchEx catch (e) { // Catch specific exception
      _handleTorchError("Error enabling torch: ${e.message}");
    } catch (e) { // Catch general errors
      _handleTorchError("Unexpected error turning torch on: $e");
    }
  }

  // Explicit OFF function using torch_light
  Future<void> _turnFlashlightOff() async {
    try {
      // Check availability first
      final bool isTorchAvailable = await TorchLight.isTorchAvailable();
      if (!isTorchAvailable) {
         // No need to show error if just trying to turn off non-existent torch
         return;
      }
      // Disable torch
      await TorchLight.disableTorch();
      if (mounted) setState(() => _isFlashlightOn = false);
      print("Flashlight turned OFF.");
    } on DisableTorchEx catch (e) { // Catch specific exception
      _handleTorchError("Error disabling torch: ${e.message}");
    } catch (e) { // Catch general errors
      _handleTorchError("Unexpected error turning torch off: $e");
    }
  }

  // Toggle function for the button
  Future<void> _toggleFlashlightButton() async {
     if (_isFlashlightOn) {
        await _turnFlashlightOff();
     } else {
        await _turnFlashlightOn();
     }
  }

  void _handleTorchError(dynamic message) { // Accept message string
     print("Flashlight Error: $message");
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Flashlight Error: $message'), backgroundColor: Colors.red));
     // Reset UI state on error?
     // if (mounted) setState(() => _isFlashlightOn = false);
  }
  // --- End Light Logic ---

  // --- "Set Over?" Logic --- (remains the same)
  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async { /* ... */ }
  // --- End "Set Over?" Logic ---


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color timerColor = Colors.white;

    return Theme(
      data: ThemeData.dark().copyWith( /* ... dark theme overrides ... */ ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>( /* ... */ ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(50.0),
            child: Container(
               padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), color: appBarColor,
               child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                     IconButton(icon: Icon(_isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30), /* ... */ onPressed: _isTimerRunning ? _pauseTimer : _startTimer),
                     ValueListenableBuilder<int>( valueListenable: _remainingSecondsNotifier, builder: (context, val, child) => Text(_formatDuration(val), /* ... */)),
                     IconButton(icon: Icon(Icons.replay, size: 28), /* ... */ onPressed: _resetAndStopTimer),
                     IconButton(icon: Icon(Icons.timer_outlined, size: 28), /* ... */ onPressed: _setTotalTimerDialog),
                     IconButton(icon: Icon(Icons.alarm_add_outlined, size: 28), /* ... */ onPressed: _setThresholdDialog),
                     // --- Updated Flashlight Button ---
                     IconButton(
                        icon: Icon(_isFlashlightOn ? Icons.flashlight_on_outlined : Icons.flashlight_off_outlined, size: 28),
                        color: _isFlashlightOn ? Colors.yellowAccent : timerColor,
                        tooltip: _isFlashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
                        onPressed: _toggleFlashlightButton, // Call button-specific toggle
                     ),
                     // --- End Update ---
                  ],
               ),
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>( /* ... StreamBuilder for list ... */ ),
      ),
    );
  }

  // --- Helper Widget to Build List Content --- (remains the same)
  Widget _buildListContent(BuildContext context, Map<String, dynamic> spotsMap, int totalSpots, int totalWaitlist, int totalBucket) { /* ... */ }
}
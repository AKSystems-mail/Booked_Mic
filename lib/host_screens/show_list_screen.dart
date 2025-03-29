// lib/host_screens/show_list_screen.dart

import 'dart:async'; // Import async library for Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart'; // Required for FilteringTextInputFormatter
import 'package:torch_controller/torch_controller.dart'; // Import torch controller
import 'package:shared_preferences/shared_preferences.dart'; // Import for settings

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
  final TorchController _torchController = TorchController();

  // --- Timer State ---
  Timer? _timer;
  int _totalSeconds = 300; // Default: 5 minutes
  int _remainingSeconds = 300;
  bool _isTimerRunning = false;
  final int _lightThresholdSeconds = 60; // Threshold for light prompt (1 minute)

  // --- Settings State ---
  bool _autoLightEnabled = false; // Default setting

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _resetTimerDisplay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Settings Loading ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoLightEnabled = prefs.getBool('autoLightEnabled') ?? false;
      // TODO: Load timer duration settings if implemented
    });
  }

  // --- Timer Logic ---
  void _startTimer() {
    if (_isTimerRunning || _remainingSeconds <= 0) return;
    setState(() { _isTimerRunning = true; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() { _remainingSeconds--; });
        if (_remainingSeconds == _lightThresholdSeconds) _handleThresholdReached();
      } else {
        _pauseTimer();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Time's Up!"), duration: Duration(seconds: 3)));
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (_isTimerRunning) setState(() { _isTimerRunning = false; });
  }

  void _resetTimerDisplay() {
     setState(() { _remainingSeconds = _totalSeconds; });
  }

  void _resetAndStopTimer() {
     _pauseTimer();
     _resetTimerDisplay();
  }

  void _setTimerDialog() async {
     int? newMinutes = await showDialog<int>( /* ... Dialog definition ... */
        context: context,
        builder: (BuildContext context) {
           TextEditingController minController = TextEditingController(text: (_totalSeconds ~/ 60).toString());
           return AlertDialog(
              title: Text("Set Timer Duration (Minutes)"),
              content: TextField(controller: minController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Minutes")),
              actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")), TextButton(onPressed: () { int? mins = int.tryParse(minController.text); Navigator.pop(context, mins); }, child: Text("Set"))],
           );
        }
     );
     if (newMinutes != null && newMinutes > 0) {
        setState(() { _totalSeconds = newMinutes * 60; _resetAndStopTimer(); });
        // TODO: Save new duration
     }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // --- Light Logic ---
  void _handleThresholdReached() {
    if (_autoLightEnabled) {
      print("Auto-light enabled, toggling flashlight.");
      _toggleFlashlight();
    } else {
      print("Auto-light disabled, showing prompt.");
      _showLightPrompt();
    }
  }

  Future<void> _showLightPrompt() async {
    if (!_isTimerRunning || !mounted) return;
    final bool? confirm = await showDialog<bool>( /* ... Dialog definition ... */
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Light Performer?'), content: Text('Time remaining is low.'),
          actions: <Widget>[ TextButton(child: Text('No'), onPressed: () => Navigator.of(context).pop(false)), TextButton(child: Text('Yes', style: TextStyle(color: Colors.orange.shade800)), onPressed: () => Navigator.of(context).pop(true))],
        );
      },
    );
    if (confirm == true) {
      print("Host chose 'Yes' to light prompt.");
      _toggleFlashlight();
    } else { print("Host chose 'No' to light prompt."); }
  }

  Future<void> _toggleFlashlight() async {
    try {
      // Removed unused variable 'hasTorch'
      await _torchController.toggle();
      print("Flashlight toggled.");
    } catch (e) {
      print("Error controlling flashlight: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not control flashlight: $e'), backgroundColor: Colors.red));
    }
  }

  // --- "Set Over?" Logic ---
  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (currentStatus) return;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          // Re-added actions to the dialog
          return AlertDialog(
             title: Text('Confirm Action'),
             content: Text('Mark "$performerName" as set over?'),
             actions: <Widget>[
                TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                TextButton(child: Text('Yes, Set Over', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop(true)),
             ],
          );
        }
    );
    if (confirm == true) {
      try {
        await _firestore.collection('Lists').doc(widget.listId).update({'spots.$spotKey.isOver': true});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2)));
      } catch (e) {
         print("Error marking spot as over: $e");
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red));
      }
    }
  }
  // --- End "Set Over?" Logic ---


  @override
  Widget build(BuildContext context) {
    final Color appBarColor = Colors.blue.shade400;
    final Color timerColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        foregroundColor: Colors.white,
        // --- CORRECTED AppBar Title StreamBuilder ---
        title: StreamBuilder<DocumentSnapshot>(
           // Provide the stream
           stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
           // Provide the builder
           builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                 // Safely access data
                 var listData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                 return Text(listData['listName'] ?? 'List Details');
              }
              // Handle loading or error state for title (optional)
              // if (snapshot.connectionState == ConnectionState.waiting) {
              //   return Text('Loading...');
              // }
              return Text('List Details'); // Default title
           }
        ),
        // --- End Correction ---
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: Container(
             padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
             color: appBarColor,
             child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   IconButton(icon: Icon(_isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30), color: timerColor, tooltip: _isTimerRunning ? 'Pause Timer' : 'Start Timer', onPressed: _isTimerRunning ? _pauseTimer : _startTimer),
                   FadeIn( key: ValueKey(_remainingSeconds), duration: Duration(milliseconds: 300), child: Text(_formatDuration(_remainingSeconds), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: timerColor, fontFamily: 'monospace'))),
                   IconButton(icon: Icon(Icons.replay, size: 28), color: timerColor, tooltip: 'Reset Timer', onPressed: _resetAndStopTimer),
                   IconButton(icon: Icon(Icons.timer_outlined, size: 28), color: timerColor, tooltip: 'Set Timer Duration', onPressed: _setTimerDialog),
                ],
             ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: appBarColor));
          if (snapshot.hasError) return Center(child: Text('Error loading list details: ${snapshot.error}', style: TextStyle(color: Colors.red.shade900)));
          if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text('List not found.'));

          var listData = snapshot.data!.data() as Map<String, dynamic>;
          final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
          final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
          final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;
          final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};

          return _buildListContent(spotsMap, totalSpots, totalWaitlist, totalBucket);
        },
      ),
    );
  }

  // --- Helper Widget to Build List Content ---
  Widget _buildListContent(
      Map<String, dynamic> spotsMap,
      int totalSpots,
      int totalWaitlist,
      int totalBucket)
  {
    List<Widget> listItems = [];

    Widget buildSpotTile(int displayIndex, SpotType type, String spotKey) {
      final spotData = spotsMap[spotKey];
      bool isAvailable = spotData == null;
      bool isReserved = spotData == 'RESERVED';
      bool isPerformerSpot = !isAvailable && !isReserved && spotData is Map;

      String titleText = 'Available'; String performerName = ''; bool isOver = false;
      Color titleColor = Colors.green.shade700; FontWeight titleWeight = FontWeight.normal;
      TextDecoration textDecoration = TextDecoration.none;

      if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange; }
      else if (isPerformerSpot) {
        final performerData = spotData as Map<String, dynamic>;
        performerName = performerData['name'] ?? 'Unknown Performer';
        isOver = performerData['isOver'] ?? false;
        titleText = performerName;
        titleColor = isOver ? Colors.grey.shade600 : Colors.black87;
        titleWeight = FontWeight.w500;
        textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none;
      }
      else if (type == SpotType.bucket && isAvailable) { titleText = 'Bucket Spot'; }

      String spotLabel;
       switch (type) { case SpotType.regular: spotLabel = "${displayIndex + 1}."; break; case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break; case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break; }

      return FadeInUp(
        delay: Duration(milliseconds: 50 * (listItems.length + 1)), duration: const Duration(milliseconds: 300),
        child: Card(
          elevation: 1.5, margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: ListTile(
            leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Colors.black54)),
            title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
            onTap: (isPerformerSpot && !isOver) ? () => _showSetOverDialog(spotKey, performerName, isOver) : null,
          ),
        ),
      );
    }

    // --- Building the list sections ---
    if (totalSpots > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), child: Text('Regular Spots', style: Theme.of(context).textTheme.titleMedium))); for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString())); } if (totalWaitlist > 0 || totalBucket > 0) listItems.add(Divider(indent: 16, endIndent: 16)); }
    if (totalWaitlist > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text('Waitlist Spots', style: Theme.of(context).textTheme.titleMedium))); for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}")); } if (totalBucket > 0) listItems.add(Divider(indent: 16, endIndent: 16)); }
    if (totalBucket > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text('Bucket Spots', style: Theme.of(context).textTheme.titleMedium))); for (int i = 0; i < totalBucket; i++) { listItems.add(buildSpotTile(i, SpotType.bucket, "B${i + 1}")); } }
    // --- End list section building ---

    if (listItems.isEmpty) return Center(child: Text("This list currently has no spots defined."));
    listItems.add(SizedBox(height: 20));
    return ListView(children: listItems);
  }
}
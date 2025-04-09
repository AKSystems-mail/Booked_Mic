// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart'; // Using torch_light
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
  // No TorchController instance needed for torch_light

  // --- Timer State ---
  Timer? _timer;
  int _totalSeconds = 300;
  late final ValueNotifier<int> _remainingSecondsNotifier;
  int _lightThresholdSeconds = 30;
  bool _isTimerRunning = false;
  bool _isFlashlightOn = false; // Track flashlight state locally

  // --- Settings State ---
  bool _autoLightEnabled = false;

  @override
  void initState() {
    super.initState();
    _remainingSecondsNotifier = ValueNotifier(_totalSeconds);
    _loadSettings();
    // Cannot easily check initial torch state with torch_light, assume off
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingSecondsNotifier.dispose();
    _turnFlashlightOff(); // Attempt to turn off on dispose
    super.dispose();
  }

  // --- Settings Loading ---
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _autoLightEnabled = prefs.getBool('autoLightEnabled_${widget.listId}') ?? false;
        _totalSeconds = prefs.getInt('timerTotal_${widget.listId}') ?? 300;
        _lightThresholdSeconds = prefs.getInt('timerThreshold_${widget.listId}') ?? 30;
        _remainingSecondsNotifier.value = _totalSeconds; // Update notifier
      });
    } catch (e) {
      print("Error loading settings: $e");
      // Handle error, maybe show default settings
    }
  }

  // --- Save Settings ---
  Future<void> _saveTimerSettings() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       await prefs.setInt('timerTotal_${widget.listId}', _totalSeconds);
       await prefs.setInt('timerThreshold_${widget.listId}', _lightThresholdSeconds);
       // await prefs.setBool('autoLightEnabled_${widget.listId}', _autoLightEnabled); // Save auto-light if UI exists
     } catch (e) {
       print("Error saving settings: $e");
     }
  }

  // --- Timer Logic ---
  void _startTimer() {
    if (_isTimerRunning || _remainingSecondsNotifier.value <= 0) return;
    setState(() { _isTimerRunning = true; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { // Check if widget is still mounted before proceeding
         timer.cancel();
         return;
      }
      if (_remainingSecondsNotifier.value > 0) {
        _remainingSecondsNotifier.value--;
        if (_remainingSecondsNotifier.value == _lightThresholdSeconds) {
          _handleThresholdReached();
        }
      } else {
        _pauseTimer();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Time's Up!"), duration: Duration(seconds: 3)));
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    if (_isTimerRunning && mounted) { // Check mounted before setState
       setState(() { _isTimerRunning = false; });
    }
  }

  void _resetTimerDisplay() {
     _remainingSecondsNotifier.value = _totalSeconds;
  }

  void _resetAndStopTimer() {
     _pauseTimer();
     _resetTimerDisplay();
  }

  void _setTotalTimerDialog() async {
     int currentMinutes = _totalSeconds ~/ 60;
     int? newMinutes = await showDialog<int>(
        context: context,
        builder: (BuildContext context) {
           TextEditingController minController = TextEditingController(text: currentMinutes.toString());
           return AlertDialog(
              title: Text("Set Total Timer (Minutes)"),
              content: TextField(controller: minController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Minutes"), autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")), TextButton(onPressed: () { int? mins = int.tryParse(minController.text); Navigator.pop(context, mins); }, child: Text("Set"))],
           );
        }
     );
     if (newMinutes != null && newMinutes > 0) {
        _totalSeconds = newMinutes * 60;
        _resetAndStopTimer();
        _saveTimerSettings();
     }
  }

  void _setThresholdDialog() async {
     int currentSeconds = _lightThresholdSeconds;
     int? newSeconds = await showDialog<int>(
        context: context,
        builder: (BuildContext context) {
           TextEditingController secController = TextEditingController(text: currentSeconds.toString());
           return AlertDialog(
              title: Text("Set Light Threshold (Seconds)"),
              content: TextField(controller: secController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Seconds Remaining"), autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")), TextButton(onPressed: () { int? secs = int.tryParse(secController.text); Navigator.pop(context, secs); }, child: Text("Set"))],
           );
        }
     );
     if (newSeconds != null && newSeconds >= 0 && newSeconds < _totalSeconds) {
        _lightThresholdSeconds = newSeconds;
        _saveTimerSettings();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold set to $_lightThresholdSeconds seconds remaining.'), duration: Duration(seconds: 2)));
     } else if (newSeconds != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold must be less than total time ($_totalSeconds sec).'), backgroundColor: Colors.orange));
     }
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
  // --- End Timer Logic ---


  // --- Light Logic using torch_light ---
  void _handleThresholdReached() {
    if (!mounted) return;
    if (_autoLightEnabled) {
      if (!_isFlashlightOn) {
         print("Auto-light enabled, turning flashlight ON.");
         _turnFlashlightOn();
      } else { print("Auto-light enabled, but flashlight already ON."); }
    } else {
      print("Auto-light disabled, showing prompt.");
      _showLightPrompt();
    }
  }

  Future<void> _showLightPrompt() async {
    if (!_isTimerRunning || !mounted) return;
    final bool? confirm = await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Light Performer?'), content: Text('Time remaining is low.'),
          actions: <Widget>[ TextButton(child: Text('No'), onPressed: () => Navigator.of(context).pop(false)), TextButton(child: Text('Yes', style: TextStyle(color: Colors.orange.shade600)), onPressed: () => Navigator.of(context).pop(true))],
        );
      },
    );
    if (confirm == true) {
      print("Host chose 'Yes' to light prompt.");
      if (!_isFlashlightOn) { _turnFlashlightOn(); }
      else { print("Flashlight already ON when prompt confirmed."); }
    } else { print("Host chose 'No' to light prompt."); }
  }

  Future<void> _turnFlashlightOn() async {
    try {
      final bool isTorchAvailable = await TorchLight.isTorchAvailable();
      if (!isTorchAvailable) { _handleTorchError("Flashlight not available."); return; }
      await TorchLight.enableTorch();
      if (mounted) setState(() => _isFlashlightOn = true);
      print("Flashlight turned ON.");
    } on Exception catch (e) { _handleTorchError("Error enabling torch: $e"); }
  }

  Future<void> _turnFlashlightOff() async {
    try {
     final bool isTorchAvailable = await TorchLight.isTorchAvailable();
     if (!isTorchAvailable) return;
      await TorchLight.disableTorch();
      // Check mounted before setState, especially in dispose
      if (mounted) setState(() => _isFlashlightOn = false);
      print("Flashlight turned OFF.");
    } on Exception catch (e) { _handleTorchError("Error disabling torch: $e"); }
  }
  
  Future<void> _toggleFlashlightButton() async {
     if (_isFlashlightOn) { await _turnFlashlightOff(); }
     else { await _turnFlashlightOn(); }
  }

  void _handleTorchError(dynamic message) {
     print("Flashlight Error: $message");
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Flashlight Error: $message'), backgroundColor: Colors.red));
  }
  // --- End Light Logic ---

  // --- "Set Over?" Logic ---
  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (currentStatus) return;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
             title: Text('Confirm Action'), content: Text('Mark "$performerName" as set over?'),
             actions: <Widget>[ TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)), TextButton(child: Text('Yes, Set Over', style: TextStyle(color: Colors.grey.shade400)), onPressed: () => Navigator.of(context).pop(true))],
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

    return Theme(
      data: ThemeData.dark().copyWith( /* ... dark theme overrides ... */ ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>(stream: _firestore.collection('Lists').doc(widget.listId).snapshots(), builder: (context, snapshot) { if (snapshot.hasData && snapshot.data!.exists) { var d = snapshot.data!.data() as Map<String, dynamic>? ?? {}; return Text(d['listName'] ?? 'List Details'); } return Text('List Details'); }),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(50.0),
            child: Container(
               padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0), color: appBarColor,
               child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                     IconButton(icon: Icon(_isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30), color: timerColor, tooltip: _isTimerRunning ? 'Pause Timer' : 'Start Timer', onPressed: _isTimerRunning ? _pauseTimer : _startTimer),
                     ValueListenableBuilder<int>( valueListenable: _remainingSecondsNotifier, builder: (context, val, child) => Text(_formatDuration(val), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: timerColor, fontFamily: 'monospace'))),
                     IconButton(icon: Icon(Icons.replay, size: 28), color: timerColor, tooltip: 'Reset Timer', onPressed: _resetAndStopTimer),
                     IconButton(icon: Icon(Icons.timer_outlined, size: 28), color: timerColor, tooltip: 'Set Total Duration', onPressed: _setTotalTimerDialog),
                     IconButton(icon: Icon(Icons.alarm_add_outlined, size: 28), color: timerColor, tooltip: 'Set Light Threshold (${_lightThresholdSeconds}s)', onPressed: _setThresholdDialog),
                     IconButton(icon: Icon(_isFlashlightOn ? Icons.flashlight_on_outlined : Icons.flashlight_off_outlined, size: 28), color: _isFlashlightOn ? Colors.yellowAccent : timerColor, tooltip: _isFlashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On', onPressed: _toggleFlashlightButton),
                  ],
               ),
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('Lists').doc(widget.listId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error loading list details: ${snapshot.error}', style: TextStyle(color: Colors.red.shade400)));
            if (!snapshot.hasData || !snapshot.data!.exists) return Center(child: Text('List not found.'));

            var listData = snapshot.data!.data() as Map<String, dynamic>;
            final spotsMap = (listData['spots'] as Map<String, dynamic>?) ?? {};
            final totalSpots = (listData['numberOfSpots'] ?? 0) as int;
            final totalWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
            final totalBucket = (listData['numberOfBucketSpots'] ?? 0) as int;

            return _buildListContent(context, spotsMap, totalSpots, totalWaitlist, totalBucket);
          },
        ),
      ),
    );
  }

  // --- Helper Widget to Build List Content ---
  Widget _buildListContent(BuildContext context, Map<String, dynamic> spotsMap, int totalSpots, int totalWaitlist, int totalBucket) {
     List<Widget> listItems = [];
     Widget buildSpotTile(int displayIndex, SpotType type, String spotKey) {
        final spotData = spotsMap[spotKey]; bool isAvailable = spotData == null; bool isReserved = spotData == 'RESERVED'; bool isPerformerSpot = !isAvailable && !isReserved && spotData is Map;
        String titleText = 'Available'; String performerName = ''; bool isOver = false;
        Color titleColor = Colors.green.shade300; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;
        if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade300; } else if (isPerformerSpot) { final performerData = spotData as Map<String, dynamic>; performerName = performerData['name'] ?? 'Unknown Performer'; isOver = performerData['isOver'] ?? false; titleText = performerName; titleColor = isOver ? Colors.grey.shade500 : Theme.of(context).listTileTheme.textColor!; titleWeight = FontWeight.w500; textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none; } else if (type == SpotType.bucket && isAvailable) { titleText = 'Bucket Spot'; }
        String spotLabel; switch (type) { case SpotType.regular: spotLabel = "${displayIndex + 1}."; break; case SpotType.waitlist: spotLabel = "W${displayIndex + 1}."; break; case SpotType.bucket: spotLabel = "B${displayIndex + 1}."; break; }
        return FadeInUp( delay: Duration(milliseconds: 50 * (listItems.length + 1)), duration: const Duration(milliseconds: 300),
           child: Card(
              child: ListTile(
                 leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Theme.of(context).listTileTheme.leadingAndTrailingTextStyle?.color)),
                 title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
                 onTap: (isPerformerSpot && !isOver) ? () => _showSetOverDialog(spotKey, performerName, isOver) : null,
              ),
           ),
        );
     }
     TextStyle headerStyle = Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8));
     if (totalSpots > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), child: Text('Regular Spots', style: headerStyle))); for (int i = 0; i < totalSpots; i++) { listItems.add(buildSpotTile(i, SpotType.regular, (i + 1).toString())); } if (totalWaitlist > 0 || totalBucket > 0) listItems.add(Divider()); }
     if (totalWaitlist > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text('Waitlist Spots', style: headerStyle))); for (int i = 0; i < totalWaitlist; i++) { listItems.add(buildSpotTile(i, SpotType.waitlist, "W${i + 1}")); } if (totalBucket > 0) listItems.add(Divider()); }
     if (totalBucket > 0) { listItems.add(Padding(padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), child: Text('Bucket Spots', style: headerStyle))); for (int i = 0; i < totalBucket; i++) { listItems.add(buildSpotTile(i, SpotType.bucket, "B${i + 1}")); } }
     if (listItems.isEmpty) return Center(child: Text("This list currently has no spots defined."));
     listItems.add(SizedBox(height: 20));
     return ListView(children: listItems);
  }
}
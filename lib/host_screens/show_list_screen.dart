// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for Timestamp if needed anywhere
import 'package:provider/provider.dart'; // Import Provider
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Models and Providers
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/providers/timer_service.dart'; // Assuming these exist
import 'package:myapp/providers/flashlight_service.dart'; // Assuming these exist
import 'package:myapp/widgets/timer_control_bar.dart'; // Assuming this exists
// Removed SpotListTile import as logic is now internal

// Define SpotType enum
enum SpotType { regular, waitlist, bucket }

// Helper Class for Reorderable List
class _SpotListItem {
  final String key;
  final SpotType type;
  final dynamic data;
  final int originalIndex;

  _SpotListItem({ required this.key, required this.type, required this.data, required this.originalIndex });

  bool get isPerformer => data != null && data is Map<String, dynamic>;
  bool get isReserved => data == 'RESERVED';
  bool get isAvailable => data == null;
  bool get isOver => isPerformer && ((data as Map<String, dynamic>)['isOver'] ?? false);
  String get performerName => isPerformer ? ((data as Map<String, dynamic>)['name'] ?? 'Unknown') : '';
  String get performerId => isPerformer ? ((data as Map<String, dynamic>)['userId'] ?? '') : '';
}


// --- Main Widget using MultiProvider ---
class ShowListScreen extends StatelessWidget {
  final String listId;
  const ShowListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    // Provide FirestoreProvider above the screen content
    return ChangeNotifierProvider<FirestoreProvider>(
      create: (_) => FirestoreProvider(),
      child: MultiProvider( // Keep MultiProvider for Timer/Flashlight if used
        providers: [
          ChangeNotifierProvider<TimerService>(
            create: (_) => TimerService(listId: listId),
          ),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
            create: (context) => FlashlightService(
              listId: listId,
              timerService: Provider.of<TimerService>(context, listen: false),
            ),
            update: (context, timerService, previous) =>
                previous?..updateTimerService(timerService) ?? // Update existing instance
                FlashlightService(listId: listId, timerService: timerService), // Or create new
          ),
        ],
        child: ShowListScreenContent(listId: listId), // Separate content widget
      ),
    );
  }
}
// --- End Main Widget ---


// --- Screen Content Widget ---
class ShowListScreenContent extends StatefulWidget {
  final String listId;
  const ShowListScreenContent({super.key, required this.listId});

  @override
  _ShowListScreenContentState createState() => _ShowListScreenContentState();
}

class _ShowListScreenContentState extends State<ShowListScreenContent> {
  // Timer State (Managed by TimerService now)
  // Flashlight State (Managed by FlashlightService now)
  // Settings State (Managed by Timer/Flashlight services now)

  // State for Reordering
  List<_SpotListItem> _orderedSpotList = [];
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    // --- Set up callbacks for FlashlightService ---
    // Use addPostFrameCallback to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
         // Access FlashlightService safely
         try {
            final flashlightService = context.read<FlashlightService>();
            flashlightService.showLightPromptCallback = _showLightPromptDialog;
            flashlightService.showErrorCallback = _showErrorSnackbar;
         } catch (e) {
            print("Error accessing FlashlightService in initState: $e");
            // Handle case where provider might not be ready immediately
         }
      }
    });
    // --- End Callback Setup ---
  }

  @override
  void dispose() {
    // Services handle their own disposal if implemented correctly
    super.dispose();
  }

  // --- Dialog Functions ---
  // These now use the providers for actions

  Future<void> _setTotalTimerDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>(); // Use read for one-off action
     int currentMinutes = timerService.totalSeconds ~/ 60;
     int? newMinutes = await showDialog<int>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
     if (newMinutes != null && newMinutes > 0) {
       await timerService.setTotalSeconds(newMinutes * 60); // Call service method
     }
  }

  Future<void> _setThresholdDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>(); // Use read
     int currentSeconds = timerService.lightThresholdSeconds;
     int? newSeconds = await showDialog<int>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
     if (newSeconds != null) {
       bool success = await timerService.setLightThreshold(newSeconds); // Call service method
       if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold must be less than total time (${timerService.totalSeconds} sec).'), backgroundColor: Colors.orange));
       } else if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold set to $newSeconds seconds remaining.'), duration: Duration(seconds: 2)));
       }
     }
  }

  // Callback function passed to FlashlightService
  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null;
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null; // Check timer state via service

     return await showDialog<bool>( context: context, barrierDismissible: false, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
     // FlashlightService will handle calling toggle based on result
  }

  // Callback function passed to FlashlightService
  void _showErrorSnackbar(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
     }
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (!mounted) return;
    if (currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
    if (confirm == true) {
      try {
        // Use FirestoreProvider
        await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2)));
      } catch (e) {
        debugPrint("Error marking spot as over: $e");
        if (mounted) _showErrorSnackbar('Error updating status: $e');
      }
    }
  }

  Future<void> _showAddNameDialog(String spotKey) async {
    if (!mounted) return;
    TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
    if (name != null && name.isNotEmpty) {
      try {
        // Use FirestoreProvider
        await context.read<FirestoreProvider>().addManualNameToSpot(widget.listId, spotKey, name);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$name" to spot $spotKey.')));
      } catch (e) {
        debugPrint("Error adding name to spot: $e");
         if (mounted) _showErrorSnackbar('Error adding name: $e');
      }
    }
  }

  Future<void> _handleDismissPerformer(String spotKey, String performerName) async {
    // Note: The original _SpotListItem doesn't easily provide performerId here.
    // If needed, FirestoreProvider.removePerformerFromSpot needs adjustment
    // or the _SpotListItem needs the ID. Assuming removal doesn't need ID for now.
    if (!mounted) return;
    try {
      // Use FirestoreProvider
      await context.read<FirestoreProvider>().removePerformerFromSpot(widget.listId, spotKey);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed "$performerName" from spot $spotKey.')));
    } catch (e) {
      debugPrint("Error removing performer: $e");
      if (mounted) _showErrorSnackbar('Error removing performer: $e');
    }
  }
  // --- End Dialog Functions ---


  // --- Function to Save Reordered List ---
  Future<void> _saveReorderedList(List<_SpotListItem> reorderedList) async {
     if (_isReordering) return;
     setState(() { _isReordering = true; });
     print("Saving reordered list...");

     Map<String, dynamic> newSpotsMap = {};
     int regularCounter = 1; int waitlistCounter = 1; int bucketCounter = 1;
     int currentRegularCount = reorderedList.where((i) => i.type == SpotType.regular).length;
     int currentWaitlistCount = reorderedList.where((i) => i.type == SpotType.waitlist).length;

     for (int i = 0; i < reorderedList.length; i++) {
        final item = reorderedList[i]; String newKey;
        if (regularCounter <= currentRegularCount) { newKey = regularCounter.toString(); regularCounter++; }
        else if (waitlistCounter <= currentWaitlistCount) { newKey = 'W$waitlistCounter'; waitlistCounter++; }
        else { newKey = 'B$bucketCounter'; bucketCounter++; }
        newSpotsMap[newKey] = item.data;
     }

     try {
        // Use FirestoreProvider - *** NEED TO ADD reorderSpots METHOD ***
        // await context.read<FirestoreProvider>().reorderSpots(widget.listId, newSpotsMap); // Assuming provider method takes the map
        // --- TEMPORARY DIRECT FIRESTORE CALL (Provider method needs adding) ---
        await FirebaseFirestore.instance.collection('Lists').doc(widget.listId).update({'spots': newSpotsMap});
        // --- END TEMPORARY ---
        print("Reordered list saved successfully.");
     } catch (e) {
        print("Error saving reordered list: $e");
        if (mounted) _showErrorSnackbar('Error saving order: $e');
     } finally {
        if (mounted) setState(() { _isReordering = false; });
     }
  }
  // --- End Save Reordered List ---

  // --- Helper to create initial ordered list ---
  List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap, int totalRegular, int totalWaitlist, int totalBucket) {
     List<_SpotListItem> items = []; int index = 0;
     void addItem(String key, dynamic data, SpotType type) { items.add(_SpotListItem(key: key, type: type, data: data, originalIndex: index++)); }
     List<int> regularKeys = []; List<int> waitlistKeysNum = []; List<int> bucketKeysNum = [];
     spotsMap.forEach((key, value) { if (int.tryParse(key) != null) regularKeys.add(int.parse(key)); else if (key.startsWith('W') && int.tryParse(key.substring(1)) != null) waitlistKeysNum.add(int.parse(key.substring(1))); else if (key.startsWith('B') && int.tryParse(key.substring(1)) != null) bucketKeysNum.add(int.parse(key.substring(1))); });
     regularKeys.sort(); waitlistKeysNum.sort(); bucketKeysNum.sort();
     for (int i = 1; i <= totalRegular; i++) { String key = i.toString(); addItem(key, spotsMap[key], SpotType.regular); }
     for (int i = 1; i <= totalWaitlist; i++) { String key = "W$i"; addItem(key, spotsMap[key], SpotType.waitlist); }
     for (int i = 1; i <= totalBucket; i++) { String key = "B$i"; addItem(key, spotsMap[key], SpotType.bucket); }
     return items;
  }
  // --- End Helper ---


  @override
  Widget build(BuildContext context) {
    // Access providers needed in build
    final firestoreProvider = context.watch<FirestoreProvider>();
    // Timer and Flashlight might be watched by TimerControlBar directly

    return Theme(
      data: ThemeData.dark().copyWith( /* ... dark theme overrides ... */ ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Show>( // Watch the Show object stream
              stream: firestoreProvider.getShow(widget.listId),
              builder: (context, snapshot) {
                if (snapshot.hasData) return Text(snapshot.data!.showName);
                return Text('List Details');
              }),
          // Use the extracted TimerControlBar widget
          bottom: TimerControlBar(
             backgroundColor: Colors.blue.shade400, // Pass color
             onSetTotalDialog: _setTotalTimerDialog,
             onSetThresholdDialog: _setThresholdDialog,
             // Pass necessary callbacks or values from Timer/Flashlight services
             // Example: Assuming TimerControlBar uses Consumer/watch internally
          ),
        ),
        body: StreamBuilder<Show>( // Main body stream watches the Show object
          stream: firestoreProvider.getShow(widget.listId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade400)));
            if (!snapshot.hasData || snapshot.data == null) return Center(child: Text('List not found.'));

            final showData = snapshot.data!; // Now we have the Show object

            // --- Use Show object data ---
            final spotsMap = showData.spots; // Access spots map from model
            final totalSpots = showData.numberOfSpots;
            final totalWaitlist = showData.waitListSpots; // Check model field name
            final totalBucket = showData.numberOfBucketSpots; // Check model field name
            // --- End Use ---

            if (!_isReordering) {
               _orderedSpotList = _createOrderedList(spotsMap, totalSpots, totalWaitlist, totalBucket);
            }

            if (_orderedSpotList.isEmpty) {
               return Center(child: Text("This list currently has no spots defined."));
            }

            // Pass the ordered list to the builder
            return _buildListWidgetContent(context, _orderedSpotList);
          },
        ),
      ),
    );
  }

  // --- Helper Widget to Build Reorderable List Content ---
  Widget _buildListWidgetContent(BuildContext context, List<_SpotListItem> spotItems) {
    return ReorderableListView.builder(
       padding: EdgeInsets.only(bottom: 80, top: 8),
       itemCount: spotItems.length,
       itemBuilder: (context, index) {
          final item = spotItems[index];
          final itemKey = ValueKey('${item.key}_${item.originalIndex}');

          // Use extracted SpotListTile widget
          return SpotListTile(
             key: itemKey, // Pass the key
             spotKey: item.key, // Pass original key for actions
             spotData: item.data,
             spotLabel: _calculateSpotLabel(item, index, spotItems), // Calculate label
             spotType: item.type,
             animationIndex: index, // Use current index for animation stagger
             onShowAddNameDialog: _showAddNameDialog, // Pass callback
             onShowSetOverDialog: _showSetOverDialog, // Pass callback
             onDismissPerformer: _handleDismissPerformer, // Pass callback
             isReorderable: true, // Enable drag handle etc.
             reorderIndex: index, // Pass current index for drag handle
          );
       },
       onReorder: (int oldIndex, int newIndex) {
          if (_isReordering) return;
          setState(() {
             if (newIndex > oldIndex) newIndex -= 1;
             final _SpotListItem item = _orderedSpotList.removeAt(oldIndex);
             _orderedSpotList.insert(newIndex, item);
             _saveReorderedList(_orderedSpotList);
          });
       },
    );
  }
  // --- End Helper ---

  // --- Helper to calculate display label ---
  String _calculateSpotLabel(_SpotListItem item, int currentIndex, List<_SpotListItem> currentList) {
      int displayNum = 1;
      int countOfType = 0;
      for(int i=0; i<=currentIndex; i++){
         if(currentList[i].type == item.type){
            countOfType++;
         }
      }
      displayNum = countOfType;

      switch (item.type) {
         case SpotType.regular: return "$displayNum.";
         case SpotType.waitlist: return "W$displayNum.";
         case SpotType.bucket: return "B$displayNum.";
      }
  }
  // --- End Helper ---

} // End of _ShowListScreenContentState class

// --- Ensure models/providers/widgets are correctly defined ---
// Example Placeholder for TimerService (replace with your actual service)
class TimerService extends ChangeNotifier {
  final String listId;
  TimerService({required this.listId}) { /* Load initial state */ }
  int totalSeconds = 300;
  int lightThresholdSeconds = 30;
  bool isTimerRunning = false;
  ValueNotifier<int> remainingSecondsNotifier = ValueNotifier(300);

  Future<void> setTotalSeconds(int seconds) async { totalSeconds = seconds; remainingSecondsNotifier.value = seconds; notifyListeners(); /* Save */ }
  Future<void> setLightThreshold(int seconds) async { if (seconds < totalSeconds) { lightThresholdSeconds = seconds; notifyListeners(); /* Save */ return true; } return false; }
  void startTimer() { /* ... */ isTimerRunning = true; notifyListeners(); }
  void pauseTimer() { /* ... */ isTimerRunning = false; notifyListeners(); }
  void resetAndStopTimer() { /* ... */ isTimerRunning = false; remainingSecondsNotifier.value = totalSeconds; notifyListeners(); }
}

// Example Placeholder for FlashlightService (replace with actual)
class FlashlightService extends ChangeNotifier {
  final String listId;
  final TimerService timerService; // Depends on TimerService
  bool isFlashlightOn = false;
  Function(String)? showErrorCallback;
  Future<bool?> Function()? showLightPromptCallback;

  FlashlightService({required this.listId, required this.timerService}) {
     // Listen to timer changes if needed
     timerService.remainingSecondsNotifier.addListener(_checkThreshold);
     // Load initial settings
  }

  void updateTimerService(TimerService newTimerService) {
     // Update listener if timer service instance changes (might not be needed with ProxyProvider)
  }

  void _checkThreshold() {
     if (timerService.remainingSecondsNotifier.value == timerService.lightThresholdSeconds) {
        // Handle threshold logic, potentially calling callbacks
        _handleThresholdReached();
     }
  }

  void _handleThresholdReached() async {
     // Load autoLightEnabled setting
     bool autoLight = false; // Replace with actual loading
     if (autoLight) {
        if (!isFlashlightOn) await toggleFlashlight();
     } else {
        final bool? result = await showLightPromptCallback?.call();
        if (result == true && !isFlashlightOn) {
           await toggleFlashlight();
        }
     }
  }

  Future<void> toggleFlashlight() async {
     try {
        await TorchLight.toggle(); // Use torch_light static method
        isFlashlightOn = !isFlashlightOn; // Assume toggle worked
        notifyListeners();
     } catch (e) {
        showErrorCallback?.call("Flashlight Error: $e");
     }
  }

  @override
  void dispose() {
    timerService.remainingSecondsNotifier.removeListener(_checkThreshold);
    super.dispose();
  }
}

// Example Placeholder for TimerControlBar (replace with actual)
class TimerControlBar extends StatelessWidget implements PreferredSizeWidget {
  final Color backgroundColor;
  final VoidCallback onSetTotalDialog;
  final VoidCallback onSetThresholdDialog;

  const TimerControlBar({
     Key? key,
     required this.backgroundColor,
     required this.onSetTotalDialog,
     required this.onSetThresholdDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to TimerService and FlashlightService
    return Consumer2<TimerService, FlashlightService>(
       builder: (context, timer, flashlight, child) {
          return Container(
             padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
             color: backgroundColor,
             child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   IconButton(icon: Icon(timer.isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30), color: Colors.white, tooltip: timer.isTimerRunning ? 'Pause Timer' : 'Start Timer', onPressed: timer.isTimerRunning ? timer.pauseTimer : timer.startTimer),
                   ValueListenableBuilder<int>( valueListenable: timer.remainingSecondsNotifier, builder: (context, val, _) => Text(_formatDurationStatic(val), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'))),
                   IconButton(icon: Icon(Icons.replay, size: 28), color: Colors.white, tooltip: 'Reset Timer', onPressed: timer.resetAndStopTimer),
                   IconButton(icon: Icon(Icons.timer_outlined, size: 28), color: Colors.white, tooltip: 'Set Total Duration', onPressed: onSetTotalDialog),
                   IconButton(icon: Icon(Icons.alarm_add_outlined, size: 28), color: Colors.white, tooltip: 'Set Light Threshold (${timer.lightThresholdSeconds}s)', onPressed: onSetThresholdDialog),
                   IconButton(icon: Icon(flashlight.isFlashlightOn ? Icons.flashlight_on_outlined : Icons.flashlight_off_outlined, size: 28), color: flashlight.isFlashlightOn ? Colors.yellowAccent : Colors.white, tooltip: flashlight.isFlashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On', onPressed: flashlight.toggleFlashlight),
                ],
             ),
          );
       }
    );
  }

  // Static helper for formatting needed here if called from static context
  static String _formatDurationStatic(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }


  @override
  Size get preferredSize => Size.fromHeight(50.0);
}

// Example Placeholder for SpotListTile (replace with actual)
class SpotListTile extends StatelessWidget {
  final String spotKey;
  final dynamic spotData;
  final String spotLabel;
  final SpotType spotType;
  final int animationIndex;
  final Function(String) onShowAddNameDialog;
  final Function(String, String, bool) onShowSetOverDialog;
  final Function(String, String) onDismissPerformer; // Takes key and name
  final bool isReorderable;
  final int reorderIndex;


  const SpotListTile({
    required Key key, // Use required Key for ReorderableListView items
    required this.spotKey,
    required this.spotData,
    required this.spotLabel,
    required this.spotType,
    required this.animationIndex,
    required this.onShowAddNameDialog,
    required this.onShowSetOverDialog,
    required this.onDismissPerformer,
    this.isReorderable = false, // Default to false if not passed
    this.reorderIndex = 0, // Default
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     // Determine state from spotData
     bool isAvailable = spotData == null;
     bool isReserved = spotData == 'RESERVED';
     bool isPerformer = !isAvailable && !isReserved && spotData is Map<String, dynamic>;
     String titleText = 'Available';
     String performerName = '';
     String performerId = ''; // Get ID if needed for dismiss
     bool isOver = false;
     Color titleColor = Colors.green.shade300;
     FontWeight titleWeight = FontWeight.normal;
     TextDecoration textDecoration = TextDecoration.none;

     if (isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade300; }
     else if (isPerformer) {
        final performerData = spotData as Map<String, dynamic>;
        performerName = performerData['name'] ?? 'Unknown Performer';
        performerId = performerData['userId'] ?? ''; // Extract ID
        isOver = performerData['isOver'] ?? false;
        titleText = performerName;
        titleColor = isOver ? Colors.grey.shade500 : Theme.of(context).listTileTheme.textColor!;
        titleWeight = FontWeight.w500;
        textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none;
     } else if (spotType == SpotType.bucket && isAvailable) { titleText = 'Bucket Spot'; }

     Widget tile = Card(
        child: ListTile(
           leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Theme.of(context).listTileTheme.leadingAndTrailingTextStyle?.color)),
           title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
           onTap: isAvailable && !isReserved
               ? () => onShowAddNameDialog(spotKey)
               : (isPerformer && !isOver)
                   ? () => onShowSetOverDialog(spotKey, performerName, isOver)
                   : null,
           trailing: isReorderable
               ? ReorderableDragStartListener(
                   index: reorderIndex,
                   child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                 )
               : null, // No trailing widget if not reorderable
        ),
     );

     // Apply dismissible if it's a performer spot that's not over
     if (isPerformer && !isOver && isReorderable) { // Only allow dismiss if reorderable context
        return Dismissible(
           key: key!, // Use the key passed from builder
           direction: DismissDirection.endToStart,
           background: Container( /* ... Dismiss background ... */ ),
           onDismissed: (direction) {
              onDismissPerformer(spotKey, performerId); // Pass ID if needed
           },
           child: tile,
        );
     } else {
        return tile;
     }
  }
}
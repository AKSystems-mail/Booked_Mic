// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Keep only if Timestamp is directly used
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart'; // Keep for FilteringTextInputFormatter in dialogs
// import 'package:torch_light/torch_light.dart'; // Not directly used here, handled by FlashlightService
// import 'package:shared_preferences/shared_preferences.dart'; // Handled by services

// Import Models and Providers
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';
import 'package:myapp/widgets/timer_control_bar.dart';

// Define SpotType enum
enum SpotType { regular, waitlist, bucket }

// Helper Class for Reorderable List
class _SpotListItem {
  final String key; final SpotType type; final dynamic data; final int originalIndex;
  _SpotListItem({ required this.key, required this.type, required this.data, required this.originalIndex });
  bool get isPerformer => data != null && data is Map<String, dynamic>;
  bool get isReserved => data == 'RESERVED';
  bool get isAvailable => data == null;
  bool get isOver => isPerformer && ((data as Map<String, dynamic>)['isOver'] ?? false);
  String get performerName => isPerformer ? ((data as Map<String, dynamic>)['name'] ?? 'Unknown') : '';
  String get performerId => isPerformer ? ((data as Map<String, dynamic>)['userId'] ?? '') : '';
}

// --- Main Widget using MultiProvider ---
// This is the entry point widget for the screen
class ShowListScreen extends StatelessWidget {
  final String listId;
  // Use super parameters
  const ShowListScreen({super.key, required this.listId});

  // --- ADDED build method ---
  @override
  Widget build(BuildContext context) {
    // Provide FirestoreProvider if not already provided higher up the tree
    // Assume TimerService and FlashlightService are specific to this screen instance
    return ChangeNotifierProvider<FirestoreProvider>(
      create: (_) => FirestoreProvider(), // Or use context.read if already provided
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TimerService>(create: (_) => TimerService(listId: listId)),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
            create: (context) => FlashlightService(listId: listId, timerService: Provider.of<TimerService>(context, listen: false)),
            update: (context, timerService, previousFlashlightService) {
               final flashlight = previousFlashlightService ?? FlashlightService(listId: listId, timerService: timerService);
               // If FlashlightService needs explicit update:
               // flashlight.updateTimerService(timerService); // Assuming this method exists
               return flashlight; // MUST return non-nullable
            }
          ),
        ],
        child: ShowListScreenContent(listId: listId), // The actual screen content
      ),
    );
  }
  // --- END ADDED build method ---
}
// --- End Main Widget ---


// --- Screen Content Widget (Stateful) ---
class ShowListScreenContent extends StatefulWidget {
  final String listId; // Needs listId passed from parent
  // Use super parameters
  const ShowListScreenContent({super.key, required this.listId});

  // --- ADDED createState method ---
  @override
  State<ShowListScreenContent> createState() => _ShowListScreenContentState();
  // --- END ADDED createState ---
}

// Make State class private
class _ShowListScreenContentState extends State<ShowListScreenContent> {
  // State for Reordering
  List<_SpotListItem> _orderedSpotList = [];
  // Make final if only modified via methods that call setState
  // bool _isReordering = false; // Keep as non-final, modified in setState
  bool _isReordering = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
         try {
            final flashlightService = context.read<FlashlightService>();
            // Assign callbacks
            flashlightService.showLightPromptCallback = _showLightPromptDialog;
            flashlightService.showErrorCallback = _showErrorSnackbar;
         } catch (e) { /* print("Error accessing FlashlightService in initState: $e"); */ }
      }
    });
  }

  // --- ADDED super.dispose() ---
  @override
  @mustCallSuper
  void dispose() {
    // Services/Notifiers dispose themselves if implemented correctly
    super.dispose(); // Call super.dispose()
  }
  // --- END ADD ---

  // --- Dialog Functions ---
  // These are called by TimerControlBar or other UI elements

  Future<void> _setTotalTimerDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>();
     int currentMinutes = timerService.totalSeconds ~/ 60;
     int? newMinutes = await showDialog<int>(
        context: context,
        builder: (BuildContext dialogContext) {
           TextEditingController minController = TextEditingController(text: currentMinutes.toString());
           return AlertDialog(
              title: Text("Set Total Timer (Minutes)"),
              content: TextField(controller: minController, /* ... */ autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")), TextButton(onPressed: () { int? mins = int.tryParse(minController.text); Navigator.pop(dialogContext, mins); }, child: Text("Set"))],
           ); // Ensure return
        }
     );
     if (newMinutes != null && newMinutes > 0) {
       await timerService.setTotalSeconds(newMinutes * 60);
     }
  }

  Future<void> _setThresholdDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>();
     int currentSeconds = timerService.lightThresholdSeconds;
     int? newSeconds = await showDialog<int>(
        context: context,
        builder: (BuildContext dialogContext) {
           TextEditingController secController = TextEditingController(text: currentSeconds.toString());
           return AlertDialog( /* ... Dialog UI ... */ ); // Ensure return
        }
     );
     if (newSeconds != null) {
       bool success = await timerService.setLightThreshold(newSeconds);
       if (!success && mounted) { /* ... Show error SnackBar ... */ }
       else if (success && mounted) { /* ... Show success SnackBar ... */ }
     }
  }

  // Return type is Future<bool?> - must handle all paths or return null explicitly
  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null; // Return null if not mounted
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null; // Return null if timer not running
     return await showDialog<bool>( // Return the result of showDialog
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); } // Ensure return
     );
  }

  void _showErrorSnackbar(String message) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); }); // Ensure return
    if (confirm == true) {
      // Add mounted check after await
      if (!mounted) return;
      try { await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true, ''); /* Pass ID if needed */ if (mounted) { /* ... SnackBar ... */ } } // Pass empty ID if not available/needed by provider
      catch (e) { /* ... Error handling ... */ }
    }
  }

  Future<void> _showAddNameDialog(String spotKey) async {
    if (!mounted) return;
    TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>( context: context, builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI using nameController ... */ ); }); // Ensure return
    if (name != null && name.isNotEmpty) {
      // Add mounted check after await
      if (!mounted) return;
      try { await context.read<FirestoreProvider>().addManualNameToSpot(widget.listId, spotKey, name); if (mounted) { /* ... SnackBar ... */ } }
      catch (e) { /* ... Error handling ... */ }
    }
  }

  Future<void> _handleDismissPerformer(String spotKey, String performerId) async {
    if (!mounted) return;
    try { await context.read<FirestoreProvider>().removePerformerFromSpot(widget.listId, spotKey); }
    catch (e) { /* ... Error handling ... */ }
  }
  // --- End Dialog Functions ---


  // --- Function to Save Reordered List ---
  // This IS used by onReorder callback
  Future<void> _saveReorderedList(List<_SpotListItem> reorderedList) async {
     if (_isReordering) return;
     setState(() { _isReordering = true; });
     // print("Saving reordered list..."); // Commented out
     Map<String, dynamic> newSpotsMap = {};
     int regularCounter = 1; int waitlistCounter = 1; int bucketCounter = 1;
     for (final item in reorderedList) { /* ... Re-keying logic ... */ }
     // Add mounted check before provider call
     if (!mounted) { setState(() => _isReordering = false); return; }
     try { await context.read<FirestoreProvider>().saveReorderedSpots(widget.listId, newSpotsMap); /* print("Reordered list saved successfully."); */ }
     catch (e) { /* print("Error saving reordered list: $e"); */ if (mounted) _showErrorSnackbar('Error saving order: $e'); }
     finally { if (mounted) setState(() { _isReordering = false; }); }
  }
  // --- End Save Reordered List ---

  // --- Helper to create initial ordered list ---
  // Added explicit return type
  List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap, int totalRegular, int totalWaitlist, int totalBucket) {
     List<_SpotListItem> items = []; int index = 0;
     void addItem(String key, dynamic data, SpotType type) { items.add(_SpotListItem(key: key, type: type, data: data, originalIndex: index++)); }
     for (int i = 1; i <= totalRegular; i++) { String key = i.toString(); addItem(key, spotsMap[key], SpotType.regular); }
     for (int i = 1; i <= totalWaitlist; i++) { String key = "W$i"; addItem(key, spotsMap[key], SpotType.waitlist); }
     for (int i = 1; i <= totalBucket; i++) { String key = "B$i"; addItem(key, spotsMap[key], SpotType.bucket); }
     return items; // Added return
  }
  // --- End Helper ---


  @override
  Widget build(BuildContext context) {
    final firestoreProvider = context.watch<FirestoreProvider>();

    return Theme(
      data: ThemeData.dark().copyWith( /* ... dark theme overrides ... */ ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Show>(
              stream: firestoreProvider.getShow(widget.listId), // Use widget.listId
              builder: (context, snapshot) { /* ... */ }
          ),
          // Pass required arguments
          bottom: TimerControlBar(
             backgroundColor: Colors.blue.shade400,
             onSetTotalDialog: _setTotalTimerDialog,
             onSetThresholdDialog: _setThresholdDialog,
          ),
        ),
        body: StreamBuilder<Show>(
          stream: firestoreProvider.getShow(widget.listId), // Use widget.listId
          builder: (context, snapshot) {
            // ... (Snapshot handling) ...
            if (!snapshot.hasData || snapshot.data == null) return Center(child: Text('List not found.'));
            final showData = snapshot.data!;
            // ... (Extract data) ...
            if (!_isReordering) { _orderedSpotList = _createOrderedList(showData.spots, showData.numberOfSpots, showData.numberOfWaitlistSpots, showData.numberOfBucketSpots); }
            if (_orderedSpotList.isEmpty) return Center(child: Text("This list currently has no spots defined."));
            // Ensure return
            return _buildListWidgetContent(context, _orderedSpotList);
          },
        ),
      ),
    );
  }

  // --- Helper Widget to Build Reorderable List Content ---
  Widget _buildListWidgetContent(BuildContext context, List<_SpotListItem> spotItems) {
    // Ensure return
    return ReorderableListView.builder(
       padding: EdgeInsets.only(bottom: 80, top: 8),
       itemCount: spotItems.length,
       itemBuilder: (context, index) { // Ensure return
          try {
             final item = spotItems[index];
             final itemKey = ValueKey('${item.key}_${item.originalIndex}');
             // Removed unused variables
             // String titleText = 'Available'; Color titleColor = Colors.green.shade300; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;
             // ... Calculate titleText, titleColor, titleWeight, textDecoration ...
             String titleText; Color titleColor; FontWeight titleWeight; TextDecoration textDecoration;
             // ... (logic as before) ...
             String spotLabel = _calculateSpotLabel(item, index, spotItems);

             Widget tileContent = FadeInUp( /* ... Animation ... */
                child: Card(
                   child: ListTile(
                      leading: Text(spotLabel, /* ... */),
                      title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
                      onTap: item.isAvailable && !item.isReserved ? () => _showAddNameDialog(item.key) : (item.isPerformer && !item.isOver) ? () => _showSetOverDialog(item.key, item.performerName, item.isOver, item.performerId) : null, // Pass performerId
                      trailing: ReorderableDragStartListener( index: index, child: Icon(Icons.drag_handle, color: Colors.grey.shade500)),
                   ),
                ),
             );

             if (item.isPerformer && !item.isOver) {
                return Dismissible( key: itemKey, /* ... */
                   onDismissed: (direction) { _handleDismissPerformer(item.key, item.performerId); setState(() { _orderedSpotList.removeAt(index); }); },
                   child: tileContent,
                ); // Ensure return
             } else {
                return Container(key: itemKey, child: tileContent); // Ensure return
             }
          } catch (e, stackTrace) {
             // print("Error building item at index $index: $e"); // Commented out
             // print(stackTrace);
             return Card(key: ValueKey('error_$index'), color: Colors.red.shade900, child: ListTile(title: Text("Error building item $index", style: TextStyle(color: Colors.white)))); // Ensure return
          }
       },
       onReorder: (int oldIndex, int newIndex) { /* ... */ },
    );
  }
  // --- End Helper ---

  // --- Helper to calculate display label ---
  // Added explicit return type String
  String _calculateSpotLabel(_SpotListItem item, int currentIndex, List<_SpotListItem> currentList) {
      try {
         int displayNum = 1; int countOfType = 0;
         for(int i=0; i < currentList.length; i++){ if(currentList[i].type == item.type){ countOfType++; if (i == currentIndex) { displayNum = countOfType; break; } } }
         switch (item.type) {
            case SpotType.regular: return "$displayNum.";
            case SpotType.waitlist: return "W$displayNum.";
            case SpotType.bucket: return "B$displayNum.";
         }
      } catch (e, stackTrace) { /* print errors */ return "Err"; }
      return "?"; // Added default return
  }
  // --- End Helper ---

} // End of _ShowListScreenContentState class
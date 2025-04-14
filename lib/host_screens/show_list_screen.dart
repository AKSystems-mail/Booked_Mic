// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
// Removed unused import: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

// Import Models and Providers
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';
import 'package:myapp/widgets/timer_control_bar.dart';
// Import needed for FilteringTextInputFormatter if used in dialogs (comes from material.dart)
import 'package:flutter/services.dart' show FilteringTextInputFormatter; // Keep if needed for dialogs specifically

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
class ShowListScreen extends StatelessWidget {
  final String listId;
  const ShowListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          // Provide FirestoreProvider if not already provided higher up
          ChangeNotifierProvider<FirestoreProvider>(create: (_) => FirestoreProvider()),
          ChangeNotifierProvider<TimerService>(create: (_) => TimerService(listId: listId)),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
            create: (context) => FlashlightService(listId: listId, timerService: Provider.of<TimerService>(context, listen: false)),
            update: (context, timerService, previousFlashlightService) {
               final flashlight = previousFlashlightService ?? FlashlightService(listId: listId, timerService: timerService);
               // flashlight.updateTimerService(timerService); // Add if needed
               return flashlight;
            }
          ),
        ],
        child: ShowListScreenContent(listId: listId),
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
  // State for Reordering
  List<_SpotListItem> _orderedSpotList = [];
  bool _isReordering = false;

  // Access providers via context where needed, no local instances needed here

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
         try {
            final flashlightService = context.read<FlashlightService>();
            flashlightService.showLightPromptCallback = _showLightPromptDialog;
            flashlightService.showErrorCallback = _showErrorSnackbar;
         } catch (e) { print("Error accessing FlashlightService in initState: $e"); }
      }
    });
  }

  // --- Dialog Functions ---

  Future<void> _setTotalTimerDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>();
     int currentMinutes = timerService.totalSeconds ~/ 60;
     int? newMinutes = await showDialog<int>(
        context: context,
        builder: (BuildContext dialogContext) {
           // Variable IS used here
           TextEditingController minController = TextEditingController(text: currentMinutes.toString());
           return AlertDialog(
              title: Text("Set Total Timer (Minutes)"),
              content: TextField(controller: minController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Minutes"), autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")), TextButton(onPressed: () { int? mins = int.tryParse(minController.text); Navigator.pop(dialogContext, mins); }, child: Text("Set"))],
           );
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
           return AlertDialog(
              title: Text("Set Light Threshold (Seconds)"),
              content: TextField(controller: secController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: "Seconds Remaining"), autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")), TextButton(onPressed: () { int? secs = int.tryParse(secController.text); Navigator.pop(dialogContext, secs); }, child: Text("Set"))],
           );
        }
     );
     if (newSeconds != null) {
       try {
          // Simply call the method, don't expect a return value
          await timerService.setLightThreshold(newSeconds);
          // Show success message if the call completes without error
          // (assuming the service handles invalid input internally)
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold setting updated (if valid).'), duration: Duration(seconds: 2)));
          }
       } catch (e) {
          // Handle potential errors thrown by the service (e.g., ArgumentError)
          print("Error setting threshold: $e");
          if (mounted) {
             _showErrorSnackbar('Failed to set threshold: $e');
          }
       }
     }
  }

  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null;
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null;
     // await is okay here, the return value IS used implicitly by the caller (FlashlightService)
     return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) { return AlertDialog( title: Text('Light Performer?'), content: Text('Time remaining is low.'), actions: <Widget>[ TextButton(child: Text('No'), onPressed: () => Navigator.of(dialogContext).pop(false)), TextButton(child: Text('Yes', style: TextStyle(color: Colors.orange.shade600)), onPressed: () => Navigator.of(dialogContext).pop(true))],); }
     );
  }

  void _showErrorSnackbar(String message) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) { return AlertDialog( title: Text('Confirm Action'), content: Text('Mark "$performerName" as set over?'), actions: <Widget>[ TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)), TextButton(child: Text('Yes, Set Over', style: TextStyle(color: Colors.grey.shade400)), onPressed: () => Navigator.of(dialogContext).pop(true))], ); }
    );
    if (confirm == true) {
      try { await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2))); }
      catch (e) { debugPrint("Error marking spot as over: $e"); if (mounted) _showErrorSnackbar('Error updating status: $e'); }
    }
  }

  Future<void> _showAddNameDialog(String spotKey) async {
    if (!mounted) return;
    // Variable IS used here
    TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) { return AlertDialog( title: Text('Add Performer Name'), content: TextField( controller: nameController, decoration: InputDecoration(labelText: 'Performer Name'), autofocus: true, ), actions: <Widget>[ TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()), TextButton(child: Text('Add'), onPressed: () => Navigator.of(dialogContext).pop(nameController.text)), ], ); }
    );
    if (name != null && name.isNotEmpty) {
      try { await context.read<FirestoreProvider>().addManualNameToSpot(widget.listId, spotKey, name); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$name" to spot $spotKey.'))); }
      catch (e) { debugPrint("Error adding name to spot: $e"); if (mounted) _showErrorSnackbar('Error adding name: $e'); }
    }
  }

  Future<void> _handleDismissPerformer(String spotKey, String performerId) async {
    if (!mounted) return;
    try { await context.read<FirestoreProvider>().removePerformerFromSpot(widget.listId, spotKey); }
    catch (e) { debugPrint("Error removing performer: $e"); if (mounted) _showErrorSnackbar('Error removing performer: $e'); }
  }
  // --- End Dialog Functions ---


  // --- Function to Save Reordered List ---
  Future<void> _saveReorderedList(List<_SpotListItem> reorderedList) async {
     if (_isReordering) return;
     setState(() { _isReordering = true; });
     print("Saving reordered list...");
     Map<String, dynamic> newSpotsMap = {};
     // These counters ARE used in the loop
     int regularCounter = 1; int waitlistCounter = 1; int bucketCounter = 1;
     for (final item in reorderedList) {
        String newKey;
        switch (item.type) {
           case SpotType.regular: newKey = regularCounter.toString(); regularCounter++; break;
           case SpotType.waitlist: newKey = 'W$waitlistCounter'; waitlistCounter++; break;
           case SpotType.bucket: newKey = 'B$bucketCounter'; bucketCounter++; break;
        }
        newSpotsMap[newKey] = item.data;
     }
     try { await context.read<FirestoreProvider>().saveReorderedSpots(widget.listId, newSpotsMap); print("Reordered list saved successfully."); }
     catch (e) { print("Error saving reordered list: $e"); if (mounted) _showErrorSnackbar('Error saving order: $e'); }
     finally { if (mounted) setState(() { _isReordering = false; }); }
  }
  // --- End Save Reordered List ---

  // --- Helper to create initial ordered list ---
  List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap, int totalRegular, int totalWaitlist, int totalBucket) {
     List<_SpotListItem> items = []; int index = 0;
     void addItem(String key, dynamic data, SpotType type) { items.add(_SpotListItem(key: key, type: type, data: data, originalIndex: index++)); }
     for (int i = 1; i <= totalRegular; i++) { String key = i.toString(); addItem(key, spotsMap[key], SpotType.regular); }
     for (int i = 1; i <= totalWaitlist; i++) { String key = "W$i"; addItem(key, spotsMap[key], SpotType.waitlist); }
     for (int i = 1; i <= totalBucket; i++) { String key = "B$i"; addItem(key, spotsMap[key], SpotType.bucket); }
     // --- Added explicit return ---
     return items;
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
              stream: firestoreProvider.getShow(widget.listId),
              builder: (context, snapshot) {
                if (snapshot.hasData) return Text(snapshot.data!.showName);
                return Text('List Details');
              }),
          bottom: TimerControlBar( // Pass required arguments
             backgroundColor: Colors.blue.shade400,
             onSetTotalDialog: _setTotalTimerDialog,
             onSetThresholdDialog: _setThresholdDialog,
          ),
        ),
        body: StreamBuilder<Show>(
          stream: firestoreProvider.getShow(widget.listId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade400)));
            if (!snapshot.hasData || snapshot.data == null) return Center(child: Text('List not found.'));

            final showData = snapshot.data!;
            final spotsMap = showData.spots;
            final totalSpots = showData.numberOfSpots;
            final totalWaitlist = showData.numberOfWaitlistSpots;
            final totalBucket = showData.numberOfBucketSpots;

            if (!_isReordering) {
               _orderedSpotList = _createOrderedList(spotsMap, totalSpots, totalWaitlist, totalBucket);
            }

            if (_orderedSpotList.isEmpty) return Center(child: Text("This list currently has no spots defined."));

            return _buildListWidgetContent(context, _orderedSpotList); // Returns Widget
          },
        ),
      ),
    );
  }

  // --- Helper Widget to Build Reorderable List Content ---
  Widget _buildListWidgetContent(BuildContext context, List<_SpotListItem> spotItems) {
    // Returns ReorderableListView which is a Widget
    return ReorderableListView.builder(
       padding: EdgeInsets.only(bottom: 80, top: 8),
       itemCount: spotItems.length,
       itemBuilder: (context, index) { // This builder MUST return a Widget
          final item = spotItems[index];
          final itemKey = ValueKey('${item.key}_${item.originalIndex}');

          String titleText = 'Available'; Color titleColor = Colors.green.shade300; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;
          if (item.isReserved) { titleText = 'Reserved'; titleColor = Colors.orange.shade300; }
          else if (item.isPerformer) { titleText = item.performerName; titleColor = item.isOver ? Colors.grey.shade500 : Theme.of(context).listTileTheme.textColor!; titleWeight = FontWeight.w500; textDecoration = item.isOver ? TextDecoration.lineThrough : TextDecoration.none; }
          else if (item.type == SpotType.bucket && item.isAvailable) { titleText = 'Bucket Spot'; }
          String spotLabel = _calculateSpotLabel(item, index, spotItems);

          Widget tileContent = FadeInUp( key: ValueKey('anim_${item.originalIndex}'), delay: Duration(milliseconds: 50 * index), duration: const Duration(milliseconds: 300),
             child: Card(
                child: ListTile(
                   leading: Text(spotLabel, style: TextStyle(fontSize: 16, color: Theme.of(context).listTileTheme.leadingAndTrailingTextStyle?.color)),
                   title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
                   onTap: item.isAvailable && !item.isReserved ? () => _showAddNameDialog(item.key) : (item.isPerformer && !item.isOver) ? () => _showSetOverDialog(item.key, item.performerName, item.isOver) : null,
                   trailing: ReorderableDragStartListener( index: index, child: Icon(Icons.drag_handle, color: Colors.grey.shade500)),
                ),
             ),
          );

          if (item.isPerformer && !item.isOver) {
             return Dismissible( key: itemKey, direction: DismissDirection.endToStart, background: Container( margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), decoration: BoxDecoration( color: Colors.red.shade400, borderRadius: BorderRadius.circular(6)), alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20.0), child: Icon(Icons.delete, color: Colors.white)),
                onDismissed: (direction) { _handleDismissPerformer(item.key, item.performerId); setState(() { _orderedSpotList.removeAt(index); }); },
                child: tileContent,
             );
          } else {
             // Ensure a widget with the key is returned
             return Container(key: itemKey, child: tileContent);
          }
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
      int displayNum = 1; int countOfType = 0;
      for(int i=0; i < currentList.length; i++){
         if(currentList[i].type == item.type){
            countOfType++;
            if (i == currentIndex) { displayNum = countOfType; break; }
         }
      }
      switch (item.type) {
         case SpotType.regular: return "$displayNum.";
         case SpotType.waitlist: return "W$displayNum.";
         case SpotType.bucket: return "B$displayNum.";
      }
      // --- Added default return ---
// Should not happen with enum
  }
  // --- End Helper ---

} // End of _ShowListScreenContentState class

// --- Remove Placeholder Widgets/Services ---
// Ensure TimerService, FlashlightService, TimerControlBar are correctly implemented elsewhere
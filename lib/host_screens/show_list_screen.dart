// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep for Timestamp
import 'package:provider/provider.dart'; // Import Provider
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Models and Providers
import 'package:myapp/models/show.dart';
import 'package:myapp/providers/firestore_provider.dart';
// Assuming TimerService and FlashlightService are correctly implemented and provided
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';
import 'package:myapp/widgets/timer_control_bar.dart';
// Assuming SpotListTile widget exists and is updated to work with _SpotListItem or Map data
import 'package:myapp/widgets/spot_list_tile.dart';


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
    // Provide FirestoreProvider if not already provided higher up the tree
    // If it's already provided by main.dart's MultiProvider, this isn't needed here.
    // return ChangeNotifierProvider<FirestoreProvider>(
    //   create: (_) => FirestoreProvider(),
    //   child: MultiProvider( // Keep for Timer/Flashlight
    return MultiProvider( // Assume FirestoreProvider is provided higher up
        providers: [
          ChangeNotifierProvider<TimerService>(create: (_) => TimerService(listId: listId)),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
            create: (context) => FlashlightService(listId: listId, timerService: Provider.of<TimerService>(context, listen: false)),
            update: (context, timerService, previous) => previous?..updateTimerService(timerService) ?? FlashlightService(listId: listId, timerService: timerService),
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
  // These now use the providers for actions

  Future<void> _setTotalTimerDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>();
     // ... (rest of dialog logic using timerService) ...
  }

  Future<void> _setThresholdDialog() async {
     if (!mounted) return;
     final timerService = context.read<TimerService>();
     // ... (rest of dialog logic using timerService) ...
  }

  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null;
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null;
     return await showDialog<bool>( context: context, barrierDismissible: false, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
  }

  void _showErrorSnackbar(String message) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
    if (confirm == true) {
      try {
        // Use FirestoreProvider
        await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2)));
      } catch (e) { debugPrint("Error marking spot as over: $e"); if (mounted) _showErrorSnackbar('Error updating status: $e'); }
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
      } catch (e) { debugPrint("Error adding name to spot: $e"); if (mounted) _showErrorSnackbar('Error adding name: $e'); }
    }
  }

  Future<void> _handleDismissPerformer(String spotKey, String performerId) async {
    // Note: performerId is available from _SpotListItem now
    if (!mounted) return;
    try {
      // Use FirestoreProvider
      await context.read<FirestoreProvider>().removePerformerFromSpot(widget.listId, spotKey);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed performer from spot $spotKey.')));
    } catch (e) { debugPrint("Error removing performer: $e"); if (mounted) _showErrorSnackbar('Error removing performer: $e'); }
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
        // Use FirestoreProvider
        await context.read<FirestoreProvider>().saveReorderedSpots(widget.listId, newSpotsMap);
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
     // ... (Logic to populate items based on total counts and spotsMap remains the same) ...
     for (int i = 1; i <= totalRegular; i++) { String key = i.toString(); addItem(key, spotsMap[key], SpotType.regular); }
     for (int i = 1; i <= totalWaitlist; i++) { String key = "W$i"; addItem(key, spotsMap[key], SpotType.waitlist); }
     for (int i = 1; i <= totalBucket; i++) { String key = "B$i"; addItem(key, spotsMap[key], SpotType.bucket); }
     return items;
  }
  // --- End Helper ---


  @override
  Widget build(BuildContext context) {
    // Access FirestoreProvider once here
    final firestoreProvider = context.watch<FirestoreProvider>();

    return Theme(
      data: ThemeData.dark().copyWith( /* ... dark theme overrides ... */ ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Show>( // Watch the Show object stream
              stream: firestoreProvider.getShow(widget.listId), // Use provider
              builder: (context, snapshot) {
                if (snapshot.hasData) return Text(snapshot.data!.showName);
                return Text('List Details');
              }),
          bottom: TimerControlBar( // Use the widget
             backgroundColor: Colors.blue.shade400,
             onSetTotalDialog: _setTotalTimerDialog,
             onSetThresholdDialog: _setThresholdDialog,
          ),
          // Add QR Code button if needed
          // actions: [ IconButton(icon: Icon(Icons.qr_code_2_outlined), onPressed: (){/* Call QR dialog */}) ],
        ),
        body: StreamBuilder<Show>( // Main body stream watches the Show object
          stream: firestoreProvider.getShow(widget.listId), // Use provider
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade400)));
            if (!snapshot.hasData || snapshot.data == null) return Center(child: Text('List not found.'));

            final showData = snapshot.data!;

            // Access data directly from the Show object
            final spotsMap = showData.spots;
            final totalSpots = showData.numberOfSpots;
            // Ensure field names here match your Show model EXACTLY
            final totalWaitlist = showData.numberOfWaitlistSpots;
            final totalBucket = showData.numberOfBucketSpots;
            // --- End Access ---

            if (!_isReordering) {
               _orderedSpotList = _createOrderedList(spotsMap, totalSpots, totalWaitlist, totalBucket);
            }

            if (_orderedSpotList.isEmpty) {
               return Center(child: Text("This list currently has no spots defined."));
            }

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
             key: itemKey,
             spotKey: item.key,
             spotData: item.data,
             spotLabel: _calculateSpotLabel(item, index, spotItems),
             spotType: item.type,
             animationIndex: index,
             onShowAddNameDialog: _showAddNameDialog,
             onShowSetOverDialog: _showSetOverDialog,
             onDismissPerformer: _handleDismissPerformer, // Pass callback
             isReorderable: true,
             reorderIndex: index,
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
      int displayNum = 1; int countOfType = 0;
      for(int i=0; i<=currentIndex; i++){ if(currentList[i].type == item.type) countOfType++; }
      displayNum = countOfType;
      switch (item.type) { case SpotType.regular: return "$displayNum."; case SpotType.waitlist: return "W$displayNum."; case SpotType.bucket: return "B$displayNum."; }
  }
  // --- End Helper ---

} // End of _ShowListScreenContentState class

// --- Ensure these widgets/providers exist and are correctly implemented ---
// class TimerService extends ChangeNotifier { /* ... */ }
// class FlashlightService extends ChangeNotifier { /* ... */ }
// class TimerControlBar extends StatelessWidget implements PreferredSizeWidget { /* ... */ }
// class SpotListTile extends StatelessWidget { /* ... */ }
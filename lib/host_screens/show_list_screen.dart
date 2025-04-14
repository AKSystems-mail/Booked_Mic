// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
// Removed unused import: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
// Removed unused import: import 'package:torch_light/torch_light.dart';
// Removed unused import: import 'package:shared_preferences/shared_preferences.dart';

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
  String get performerId => isPerformer ? ((data as Map<String, dynamic>)['userId'] ?? '') : ''; // Crucial getter
}

// --- Main Widget using MultiProvider ---
class ShowListScreen extends StatelessWidget { /* ... */ }
// --- End Main Widget ---


// --- Screen Content Widget ---
class ShowListScreenContent extends StatefulWidget { /* ... */ }

class _ShowListScreenContentState extends State<ShowListScreenContent> {
  // ... (State variables: _orderedSpotList, _isReordering) ...
  List<_SpotListItem> _orderedSpotList = [];
  bool _isReordering = false;

  @override
  void initState() { /* ... */ }

  // --- Dialog Functions ---
  Future<void> _setTotalTimerDialog() async { /* ... */ }
  Future<void> _setThresholdDialog() async { /* ... */ }
  Future<bool?> _showLightPromptDialog() async { /* ... */ }
  void _showErrorSnackbar(String message) { /* ... */ }

  // --- MODIFIED _showSetOverDialog ---
  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus, String performerId) async {
    // Pass performerId
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { /* ... Dialog UI ... */ });
    if (confirm == true) {
      try {
        // Use FirestoreProvider and pass performerId
        await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true, performerId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2)));
      } catch (e) { debugPrint("Error marking spot as over: $e"); if (mounted) _showErrorSnackbar('Error updating status: $e'); }
    }
  }
  // --- END MODIFICATION ---

  Future<void> _showAddNameDialog(String spotKey) async { /* ... */ }
  Future<void> _handleDismissPerformer(String spotKey, String performerId) async { /* ... */ }
  // --- End Dialog Functions ---


  // --- Function to Save Reordered List --- (remains the same)
  Future<void> _saveReorderedList(List<_SpotListItem> reorderedList) async { /* ... */ }
  // --- End Save Reordered List ---

  // --- Helper to create initial ordered list --- (remains the same)
  List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap, int totalRegular, int totalWaitlist, int totalBucket) { /* ... */ }
  // --- End Helper ---


  @override
  Widget build(BuildContext context) { /* ... Build method structure ... */
     final firestoreProvider = context.watch<FirestoreProvider>();
     return Theme(
       data: ThemeData.dark().copyWith( /* ... */ ),
       child: Scaffold(
         appBar: AppBar( /* ... */ ),
         body: StreamBuilder<Show>(
           stream: firestoreProvider.getShow(widget.listId),
           builder: (context, snapshot) {
             // ... (Snapshot handling) ...
             if (!snapshot.hasData || snapshot.data == null) return Center(child: Text('List not found.'));
             final showData = snapshot.data!;
             // ... (Extract data) ...
             if (!_isReordering) { _orderedSpotList = _createOrderedList(showData.spots, showData.numberOfSpots, showData.numberOfWaitlistSpots, showData.numberOfBucketSpots); }
             if (_orderedSpotList.isEmpty) return Center(child: Text("This list currently has no spots defined."));
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

          // Build tile content directly
          String titleText = 'Available'; Color titleColor = Colors.green.shade300; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;
          if (item.isReserved) { /* ... */ }
          else if (item.isPerformer) { /* ... */ }
          else if (item.type == SpotType.bucket && item.isAvailable) { /* ... */ }
          String spotLabel = _calculateSpotLabel(item, index, spotItems);

          Widget tileContent = FadeInUp( /* ... Animation ... */
             child: Card(
                child: ListTile(
                   leading: Text(spotLabel, /* ... */),
                   title: Text(titleText, /* ... */),
                   // --- MODIFIED onTap ---
                   onTap: item.isAvailable && !item.isReserved
                       ? () => _showAddNameDialog(item.key)
                       : (item.isPerformer && !item.isOver)
                           // Pass performerId to the dialog function
                           ? () => _showSetOverDialog(item.key, item.performerName, item.isOver, item.performerId)
                           : null,
                   // --- END MODIFICATION ---
                   trailing: ReorderableDragStartListener( index: index, child: Icon(Icons.drag_handle, color: Colors.grey.shade500)),
                ),
             ),
          );

          // Apply Dismissible
          if (item.isPerformer && !item.isOver) {
             return Dismissible( key: itemKey, /* ... */
                onDismissed: (direction) {
                   // Pass performerId here
                   _handleDismissPerformer(item.key, item.performerId);
                   setState(() { _orderedSpotList.removeAt(index); });
                },
                child: tileContent,
             );
          } else {
             return Container(key: itemKey, child: tileContent);
          }
       },
       onReorder: (int oldIndex, int newIndex) { /* ... */ },
    );
  }
  // --- End Helper ---

  // --- Helper to calculate display label --- (remains the same)
  String _calculateSpotLabel(_SpotListItem item, int currentIndex, List<_SpotListItem> currentList) { /* ... */ }
  // --- End Helper ---

} // End of _ShowListScreenContentState class
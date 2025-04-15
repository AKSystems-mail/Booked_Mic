// lib/widgets/spot_list_tile.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart'; // Assuming you use animation here
import 'package:myapp/host_screens/show_list_screen.dart'; // Import enum definition

// Assuming _SpotListItem is NOT defined here but passed via spotData or similar

class SpotListTile extends StatelessWidget {
  final String spotKey;
  final dynamic spotData; // Can be Map, null, or 'RESERVED'
  final String spotLabel;
  final SpotType spotType; // Use the enum
  final int animationIndex;
  final Function(String) onShowAddNameDialog;
  final Function(String, String, bool, String) onShowSetOverDialog; // Added performerId
  final Function(String, String) onDismissPerformer; // Takes key and performerId
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
    this.isReorderable = false,
    this.reorderIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     // Determine state from spotData
     bool isAvailable = spotData == null;
     // --- CORRECTED TYPE CHECK ---
     bool isReserved = spotData is String && spotData == 'RESERVED';
     // --- END CORRECTION ---
     bool isPerformer = !isAvailable && !isReserved && spotData is Map<String, dynamic>;
     String titleText = 'Available';
     String performerName = '';
     String performerId = '';
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
                   // Pass performerId to set over dialog
                   ? () => onShowSetOverDialog(spotKey, performerName, isOver, performerId)
                   : null,
           trailing: isReorderable
               ? ReorderableDragStartListener(
                   index: reorderIndex,
                   child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                 )
               : null,
        ),
     );

     // Apply dismissible if it's a performer spot that's not over
     if (isPerformer && !isOver && isReorderable) {
        return Dismissible(
           key: key!, // Use the key passed from builder
           direction: DismissDirection.endToStart,
           background: Container( /* ... Dismiss background ... */ ),
           onDismissed: (direction) {
              onDismissPerformer(spotKey, performerId); // Pass ID
           },
           child: tile,
        );
     } else {
        return tile;
     }
  }
}
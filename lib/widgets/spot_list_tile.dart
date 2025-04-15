// lib/widgets/spot_list_tile.dart
import 'package:flutter/material.dart';
// Removed unused import: import 'package:animate_do/animate_do.dart';
// Import enum from its definition file, NOT show_list_screen
import 'package:myapp/models/spot_type.dart'; // Assuming you have this file

class SpotListTile extends StatelessWidget {
  final String spotKey;
  final dynamic spotData;
  final String spotLabel;
  final SpotType spotType;
  final int animationIndex;
  final Function(String) onShowAddNameDialog;
  final Function(String, String, bool, String) onShowSetOverDialog; // Added performerId
  final Function(String, String) onDismissPerformer;
  final bool isReorderable;
  final int reorderIndex;


  const SpotListTile({
    required Key key,
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
     bool isAvailable = spotData == null;
     // --- CORRECTED TYPE CHECK ---
     bool isReserved = spotData is String && spotData == 'RESERVED';
     // --- END CORRECTION ---
     bool isPerformer = !isAvailable && !isReserved && spotData is Map<String, dynamic>;
     String titleText = 'Available'; String performerName = ''; String performerId = ''; bool isOver = false;
     Color titleColor = Colors.green.shade300; FontWeight titleWeight = FontWeight.normal; TextDecoration textDecoration = TextDecoration.none;

     if (isReserved) { /* ... */ }
     else if (isPerformer) {
        final performerData = spotData as Map<String, dynamic>;
        performerName = performerData['name'] ?? 'Unknown Performer';
        performerId = performerData['userId'] ?? '';
        isOver = performerData['isOver'] ?? false;
        titleText = performerName;
        titleColor = isOver ? Colors.grey.shade500 : Theme.of(context).listTileTheme.textColor!;
        titleWeight = FontWeight.w500;
        textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none;
     } else if (spotType == SpotType.bucket && isAvailable) { /* ... */ }

     Widget tile = Card(
        child: ListTile(
           leading: Text(spotLabel, /* ... */),
           title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
           onTap: isAvailable && !isReserved
               ? () => onShowAddNameDialog(spotKey)
               : (isPerformer && !isOver)
                   ? () => onShowSetOverDialog(spotKey, performerName, isOver, performerId) // Pass ID
                   : null,
           trailing: isReorderable
               ? ReorderableDragStartListener( index: reorderIndex, child: Icon(Icons.drag_handle, color: Colors.grey.shade500))
               : null,
        ),
     );

     // Apply dismissible if needed (logic moved back to show_list_screen)
     // if (isPerformer && !isOver && isReorderable) { ... }

     return tile; // Return the Card/ListTile directly
  }
}
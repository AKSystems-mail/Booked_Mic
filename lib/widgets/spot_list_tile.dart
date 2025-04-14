// widgets/spot_list_tile.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart'; // Keep animation
// To call Firestore actions
import 'package:myapp/models/spot_type.dart';

// Define SpotType enum if not globally available
// enum SpotType { regular, waitlist, bucket } // Make sure this is accessible

class SpotListTile extends StatelessWidget {
  final String spotKey; // e.g., "1", "W1", "B1"
  final Map<String, dynamic>? spotData; // Performer map, 'RESERVED', or null
  final String spotLabel; // e.g., "1.", "W1.", "B1."
  final SpotType spotType;
  final int animationIndex; // For FadeInUp delay

  // Callbacks for actions - defined in parent (ShowListScreen)
  final Future<void> Function(String spotKey) onShowAddNameDialog;
  final Future<void> Function(String spotKey, String performerName, bool currentStatus) onShowSetOverDialog;
  final Future<void> Function(String spotKey, String performerName) onDismissPerformer;

  const SpotListTile({
    super.key,
    required this.spotKey,
    required this.spotData,
    required this.spotLabel,
    required this.spotType,
    required this.animationIndex,
    required this.onShowAddNameDialog,
    required this.onShowSetOverDialog,
    required this.onDismissPerformer,
  });

  @override
  Widget build(BuildContext context) {
    // Determine state from spotData
    final bool isAvailable = spotData == null;
    final bool isReserved = spotData == 'RESERVED';
    final bool isPerformerSpot = !isAvailable && !isReserved && spotData is Map<String, dynamic>;

    String titleText = 'Available';
    String performerName = '';
    bool isOver = false;
    Color titleColor = Colors.green.shade300; // Default for available
    FontWeight titleWeight = FontWeight.normal;
    TextDecoration textDecoration = TextDecoration.none;

    // --- TODO: This block might cause issues if spotData is invalid ---
    // Add defensive checks if spotData format isn't guaranteed
     if (!isPerformerSpot && !isReserved && !isAvailable) {
         // Handle potential invalid data state? Default to available for now
         // isAvailable = true; // Re-assess if needed
         debugPrint("Warning: Spot $spotKey has unexpected data: $spotData");
         titleText = 'Error: Invalid Data';
         titleColor = Colors.red.shade300;
     }
     // --- End potential issue block ---


    if (isReserved) {
      titleText = 'Reserved';
      titleColor = Colors.orange.shade300;
    } else if (isPerformerSpot) {
      final performerData = spotData!; // Safe now due to isPerformerSpot check
      performerName = performerData['name'] ?? 'Unknown Performer';
      // --- Assumption: 'isOver' field exists/will be added ---
      isOver = performerData['isOver'] ?? false;
      // ------------------------------------------------------
      titleText = performerName;
      titleColor = isOver ? Colors.grey.shade500 : Colors.white; // Assuming dark theme context
      titleWeight = FontWeight.w500;
      textDecoration = isOver ? TextDecoration.lineThrough : TextDecoration.none;
    } else if (spotType == SpotType.bucket && isAvailable) {
      titleText = 'Bucket Spot';
      // titleColor = Colors.green.shade300; // Already default
    }
     // Else: Regular available spot, defaults are fine

    // Build the core ListTile content
    Widget tileContent = Card(
      key: ValueKey<String>('card_$spotKey'), // Ensure unique key
      child: ListTile(
        leading: Text(spotLabel, style: TextStyle(fontSize: 16)), // Adapt color if needed
        title: Text(
          titleText,
          style: TextStyle(
              color: titleColor,
              fontWeight: titleWeight,
              decoration: textDecoration),
        ),
        onTap: isAvailable && !isReserved
            ? () => onShowAddNameDialog(spotKey) // Trigger dialog via callback
            : (isPerformerSpot && !isOver)
                ? () => onShowSetOverDialog(spotKey, performerName, isOver) // Trigger dialog via callback
                : null,
      ),
    );

    // Wrap with Dismissible if it's a performer spot that isn't over
    Widget finalTile;
    if (isPerformerSpot && !isOver) {
      finalTile = Dismissible(
        key: ValueKey<String>('dismissible_$spotKey'), // Ensure unique key
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red.shade400,
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          child: Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) {
          // Call parent method via callback
          onDismissPerformer(spotKey, performerName);
        },
        // --- TODO: Add confirmDismiss dialog ---
        // confirmDismiss: (direction) async { ... show confirmation dialog ... },
        child: tileContent,
      );
    } else {
      finalTile = tileContent;
    }

    // Wrap with animation
    return FadeInUp(
      delay: Duration(milliseconds: 50 * animationIndex),
      duration: const Duration(milliseconds: 300),
      child: finalTile,
    );
  }
}
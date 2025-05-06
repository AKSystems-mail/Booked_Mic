import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:animate_do/animate_do.dart';
import 'package:random_text_reveal/random_text_reveal.dart'; // <<< 1. Import random_text_reveal
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter

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
  final String key;
  final SpotType type;
  final dynamic data;
  final int originalIndex;
  _SpotListItem(
      {required this.key,
      required this.type,
      required this.data,
      required this.originalIndex});
  bool get isPerformer => data != null && data is Map<String, dynamic>;
  bool get isReserved => data == 'RESERVED';
  bool get isAvailable => data == null; // No performer data and not reserved
  bool get isOver =>
      isPerformer && ((data as Map<String, dynamic>)['isOver'] ?? false);
  String get performerName =>
      isPerformer ? ((data as Map<String, dynamic>)['name'] ?? 'Unknown') : '';
  String get performerId =>
      isPerformer ? ((data as Map<String, dynamic>)['userId'] ?? '') : '';
}

// --- Main Widget using MultiProvider ---
class ShowListScreen extends StatelessWidget {
  final String listId;
  const ShowListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    // FirestoreProvider is now provided higher up if it's for the whole screen lifecycle
    // If only for this screen, this is fine.
    return ChangeNotifierProvider<FirestoreProvider>(
      create: (_) => FirestoreProvider(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TimerService>(
              create: (_) => TimerService(listId: listId)),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
              create: (context) => FlashlightService(
                  listId: listId,
                  timerService:
                      Provider.of<TimerService>(context, listen: false)),
              update: (context, timerService, previousFlashlightService) {
                final flashlight = previousFlashlightService ??
                    FlashlightService(listId: listId, timerService: timerService);
                return flashlight;
              }),
        ],
        child: ShowListScreenContent(listId: listId),
      ),
    );
  }
}

// --- Screen Content Widget (Stateful) ---
class ShowListScreenContent extends StatefulWidget {
  final String listId;
  const ShowListScreenContent({super.key, required this.listId});

  @override
  State<ShowListScreenContent> createState() => _ShowListScreenContentState();
}

class _ShowListScreenContentState extends State<ShowListScreenContent> {
  List<_SpotListItem> _orderedSpotList = [];
  bool _isReordering = false;

  // --- State for Bucket Draw Animation ---
  Map<String, bool> _isDrawingForSpot = {}; // Key: spotKey, Value: true if currently drawing
  Map<String, String?> _drawnSpotNameForAnimation = {}; // Key: spotKey, Value: name to animate/revealed
  Map<String, GlobalKey<RandomTextRevealState>> _revealControllerKeys = {}; // Keys for RandomTextReveal

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final flashlightService = context.read<FlashlightService>();
          flashlightService.showLightPromptCallback = _showLightPromptDialog;
          flashlightService.showErrorCallback = _showErrorSnackbar;
        } catch (e) {
          // print("Error setting up flashlight callbacks: $e");
        }
      }
    });
  }

  @override
  @mustCallSuper
  void dispose() {
    // Dispose any other controllers if necessary
    super.dispose();
  }

  Future<void> _setTotalTimerDialog() async {
    if (!mounted) return;
    final timerService = context.read<TimerService>();
    int currentMinutes = timerService.totalSeconds ~/ 60;
    int? newMinutes = await showDialog<int>(
        context: context,
        builder: (BuildContext dialogContext) {
          TextEditingController minController =
              TextEditingController(text: currentMinutes.toString());
          return AlertDialog(
            title: Text("Set Total Timer (Minutes)"),
            content: TextField(
              controller: minController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    int? mins = int.tryParse(minController.text);
                    Navigator.pop(dialogContext, mins);
                  },
                  child: Text("Set"))
            ],
          );
        });
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
          TextEditingController secController =
              TextEditingController(text: currentSeconds.toString());
          return AlertDialog(
            title: Text("Set Light Threshold (Seconds)"),
            content: TextField(
              controller: secController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    int? secs = int.tryParse(secController.text);
                    Navigator.pop(dialogContext, secs);
                  },
                  child: Text("Set"))
            ],
          );
        });
    if (!mounted) return;
    if (newSeconds != null) {
      try {
        await timerService.setLightThreshold(newSeconds);
      } catch (e) {
         // Error message now comes from TimerService if threshold is invalid
        _showErrorSnackbar('Failed to set threshold: $e');
      }
    }
  }

  Future<bool?> _showLightPromptDialog() async {
    if (!mounted) return null;
    final timerService = context.read<TimerService>();
    if (!timerService.isTimerRunning) return null; // Don't show if timer isn't active
    return await showDialog<bool>(
        context: context,
        barrierDismissible: false, // User must interact
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Light Performers?'),
            content: Text(
                'The timer threshold has been reached. Would you like to flash the light?'),
            actions: <Widget>[
              TextButton(
                child: Text('Not Now'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  //timerService.snoozeLightPrompt();
                },
              ),
              TextButton(
                child: Text('Yes, Flash Light'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        });
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName,
      bool currentStatus, String performerId) async {
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Confirm Action'),
            content: Text('Mark "$performerName" as set over?'),
            actions: <Widget>[
              TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false)),
              TextButton(
                  child: Text('Yes, Set Over',
                      style: TextStyle(color: const Color.fromARGB(255, 65, 21, 105))), // Consider Theme color
                  onPressed: () => Navigator.of(dialogContext).pop(true))
            ],
          );
        });
    if (confirm == true) {
      if (!mounted) return;
      try {
        await context
            .read<FirestoreProvider>()
            .setSpotOver(widget.listId, spotKey, true, performerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('"$performerName" marked as over.'),
              duration: Duration(seconds: 2)));
        }
      } catch (e) {
        if (mounted) _showErrorSnackbar('Error updating status: $e');
      }
    }
  }

  Future<void> _showAddNameDialog(String spotKey) async {
    if (!mounted) return;
    TextEditingController nameController = TextEditingController();

    final String? name = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Add Performer Name'),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Performer Name'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: Text('Add'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(nameController.text.trim()),
              ),
            ],
          );
        });

    if (!mounted) return;

    if (name != null && name.isNotEmpty) {
      try {
        await context
            .read<FirestoreProvider>()
            .addManualNameToSpot(widget.listId, spotKey, name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added "$name" to spot $spotKey.')));
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Error adding name: $e');
        }
      }
    }
  }
  // --- BUCKET DRAW LOGIC ---
  Future<void> _handleBucketDraw(String spotKey) async {
    if (!mounted || (_isDrawingForSpot[spotKey] ?? false)) return;

    if (!_revealControllerKeys.containsKey(spotKey)) {
      _revealControllerKeys[spotKey] = GlobalKey<RandomTextRevealState>();
    }

    setState(() {
      _isDrawingForSpot[spotKey] = true;
      _drawnSpotNameForAnimation[spotKey] = "Picking..."; // Initial text for animation
    });

    // Allow UI to build with "Picking..." state for RandomTextReveal
    await WidgetsBinding.instance.endOfFrame;
    _revealControllerKeys[spotKey]?.currentState?.play();

    try {
      final firestoreProvider = context.read<FirestoreProvider>();
      final drawnSpotData = await firestoreProvider.drawAndAssignBucketSpot(widget.listId, spotKey);

      if (mounted) {
        if (drawnSpotData != null && drawnSpotData['name'] != null) {
          final drawnName = drawnSpotData['name'] as String;
          setState(() {
            _drawnSpotNameForAnimation[spotKey] = drawnName; // Set the actual name to reveal
          });
          await WidgetsBinding.instance.endOfFrame; // Allow UI to build with new target text
          _revealControllerKeys[spotKey]?.currentState?.play(); // Play animation to reveal the actual name

          // Wait for the reveal animation to complete before StreamBuilder potentially takes over
          await Future.delayed(const Duration(seconds: 2, milliseconds: 300)); // Match animation + buffer
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No more names to pull.'), backgroundColor: Colors.orange),
          );
          if (mounted) { // Reset if no name was drawn
            setState(() {
              _isDrawingForSpot[spotKey] = false;
              _drawnSpotNameForAnimation[spotKey] = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error drawing from bucket: ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() { // Reset on error
          _isDrawingForSpot[spotKey] = false;
          _drawnSpotNameForAnimation[spotKey] = null;
        });
      }
    }
    // The StreamBuilder will reflect the permanent state.
    // If the draw was successful, the spot will no longer be "available" in the next stream update,
    // so the animation widget won't be built for it.
    // If it failed, we've reset _isDrawingForSpot, so it goes back to "Tap to Draw".
  }
  // --- END BUCKET DRAW LOGIC ---

  Future<void> _handleDismissPerformer(
      String spotKey, String performerId, String performerName) async {
    if (!mounted) return;
    try {
      await context
          .read<FirestoreProvider>()
          .removePerformerFromSpot(widget.listId, spotKey);
    } catch (e) {
      if (mounted) _showErrorSnackbar('Error removing performer: $e');
    }
  }

  Future<void> _saveReorderedList(List<_SpotListItem> reorderedList) async {
    if (_isReordering || !mounted) return;
    setState(() {
      _isReordering = true;
    });
    // Continuing from _saveReorderedList method in _ShowListScreenContentState

    Map<String, dynamic> newSpotsMap = {};
    int regularCounter = 1;
    int waitlistCounter = 1;
    int bucketCounter = 1;

    for (final item in reorderedList) {
      String newKey;
      switch (item.type) {
        case SpotType.regular:
          newKey = regularCounter.toString();
          regularCounter++;
          break;
        case SpotType.waitlist:
          newKey = 'W$waitlistCounter';
          waitlistCounter++;
          break;
        case SpotType.bucket:
          newKey = 'B$bucketCounter';
          bucketCounter++;
          break;
      }
      newSpotsMap[newKey] = item.data;
    }

    // if (!mounted) return; // This check was already done at the beginning of the function

    try {
      // Use Provider to save the updated map
      await context
          .read<FirestoreProvider>()
          .saveReorderedSpots(widget.listId, newSpotsMap);
      // print("Reordered list saved successfully.");
    } catch (e) {
      // print("Error saving reordered list: $e");
      if (mounted) _showErrorSnackbar('Error saving order: $e');
    } finally {
      // Allow stream to update the local list again and rebuild _orderedSpotList
      if (mounted) {
        setState(() {
          _isReordering = false;
        });
      }
    }
  } // End of _saveReorderedList

  List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap,
      int totalRegular, int totalWaitlist, int totalBucket) {
    List<_SpotListItem> items = [];
    int index = 0; // Used for originalIndex to maintain stable keys for ReorderableListView

    void addItem(String key, dynamic data, SpotType type) {
      items.add(_SpotListItem(
          key: key, type: type, data: data, originalIndex: index++));
      // Ensure a GlobalKey for RandomTextReveal is created for each bucket spot if not already present
      if (type == SpotType.bucket && !_revealControllerKeys.containsKey(key)) {
          _revealControllerKeys[key] = GlobalKey<RandomTextRevealState>();
      }
    }

    for (int i = 1; i <= totalRegular; i++) {
      String key = i.toString();
      addItem(key, spotsMap[key], SpotType.regular);
    }
    for (int i = 1; i <= totalWaitlist; i++) {
      String key = "W$i";
      addItem(key, spotsMap[key], SpotType.waitlist);
    }
    for (int i = 1; i <= totalBucket; i++) {
      String key = "B$i";
      addItem(key, spotsMap[key], SpotType.bucket);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final firestoreProvider = context.watch<FirestoreProvider>();
    final timerService = context.watch<TimerService>(); // Watch for timer updates

    // Determine AppBar title and background color based on timer state
    String appBarTitle = 'List Details'; // Default title
    Color appBarBackgroundColor = Colors.blue.shade400; // Default color

    if (timerService.isTimerRunning || timerService.isPaused) {
        appBarBackgroundColor = Colors.indigo.shade700; // Color when timer is active/paused
    }


    return Theme(
      data: ThemeData.dark().copyWith(
        // Customize your dark theme further if needed
        scaffoldBackgroundColor: Colors.grey[850], // Example dark background
        appBarTheme: AppBarTheme(
          backgroundColor: appBarBackgroundColor, // Dynamic AppBar color
          elevation: 0,
        ),
        cardColor: Colors.grey[800], // Darker cards
        // Add other theme properties as needed
      ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Show>(
            stream: firestoreProvider.getShow(widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { // More specific check
                return Text('Loading List...');
              } else if (snapshot.hasError) {
                return Text('Error Loading Title');
              } else if (!snapshot.hasData || snapshot.data == null) {
                return Text('List Not Found');
              } else {
                appBarTitle = snapshot.data!.showName; // Update title when data arrives
                return Text(appBarTitle);
              }
            },
          ),
          bottom: TimerControlBar(
            backgroundColor: appBarBackgroundColor, // Match AppBar color
            onSetTotalDialog: _setTotalTimerDialog,
            onSetThresholdDialog: _setThresholdDialog,
          ),
        ),
        body: StreamBuilder<Show>(
          stream: firestoreProvider.getShow(widget.listId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading list: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text('List not found.'));
            } else {
              final showData = snapshot.data!;
              // Only rebuild _orderedSpotList if not currently reordering
              // and if the incoming spots data has actually changed.
              // This prevents unnecessary list rebuilds during simple timer updates.
              // A more sophisticated check might involve deep comparing showData.spots.
              if (!_isReordering) {
                _orderedSpotList = _createOrderedList(
                  showData.spots,
                  showData.numberOfSpots,
                  showData.numberOfWaitlistSpots,
                  showData.numberOfBucketSpots,
                );
              }

              if (_orderedSpotList.isEmpty) {
                return Center(
                    child: Text("This list currently has no spots defined.",
                        style: TextStyle(color: Colors.grey[400])));
              }
              return _buildListWidgetContent(context, _orderedSpotList, showData); // Pass showData
            }
          },
        ),
      ),
    );
  }

  Widget _buildListWidgetContent(BuildContext context, List<_SpotListItem> spotItems, Show showData) {
    // Pass showData
    return ReorderableListView.builder(
      padding: EdgeInsets.only(bottom: 80, top: 8), // Padding for FAB and Timer Bar
      itemCount: spotItems.length,
      itemBuilder: (context, index) {
        try {
          final item = spotItems[index];
          // Use a more stable key for ReorderableListView if originalIndex can change due to filtering/sorting
          // For now, assuming originalIndex is stable for a given spot type and its position
          final itemKey = ValueKey('${item.key}_${item.type}_${item.originalIndex}');

          String titleText = 'Available';
          Color titleColor = Colors.green.shade400; // Brighter green for dark theme
          FontWeight titleWeight = FontWeight.normal;
          TextDecoration textDecoration = TextDecoration.none;
          Widget? trailingWidget = ReorderableDragStartListener( // Default trailing
            index: index,
            child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
          );
          VoidCallback? onTapAction;

          bool isCurrentlyDrawing = _isDrawingForSpot[item.key] ?? false;

          if (item.isPerformer) {
            titleText = item.performerName;
            titleColor = Colors.blue.shade300; // Brighter blue
            titleWeight = FontWeight.bold;
            textDecoration =
                item.isOver ? TextDecoration.lineThrough : TextDecoration.none;
            if (!item.isOver) {
              onTapAction = () => _showSetOverDialog(
                  item.key, item.performerName, item.isOver, item.performerId);
            }
          } else if (item.isReserved) {
            titleText = 'Reserved';
            titleColor = Colors.orange.shade400; // Brighter orange
            titleWeight = FontWeight.bold;
          } else if (item.type == SpotType.bucket && item.isAvailable) {
            if (isCurrentlyDrawing) {
              titleText = " "; // Placeholder for RandomTextReveal
              trailingWidget = SizedBox(
                width: 24, height: 24, // Smaller spinner
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).primaryColorLight),
              );
            } else {
              titleText = 'Tap to Draw from Bucket';
              titleColor = Colors.teal.shade300; // Distinct color for bucket
              onTapAction = () => _handleBucketDraw(item.key);
            }
          } else if (item.isAvailable) { // Regular or Waitlist available
            titleText = 'Available';
            onTapAction = () => _showAddNameDialog(item.key);
          }

          String spotLabel = _calculateSpotLabel(item, index, spotItems);

          Widget titleWidget;
          if (item.type == SpotType.bucket && item.isAvailable && isCurrentlyDrawing) {
            // Ensure GlobalKey exists for this spot
             if (!_revealControllerKeys.containsKey(item.key)) {
               _revealControllerKeys[item.key] = GlobalKey<RandomTextRevealState>();
             }
            titleWidget = RandomTextReveal(
              key: _revealControllerKeys[item.key], // Use the specific key
              text: _drawnSpotNameForAnimation[item.key] ?? "Picking...",
              duration: const Duration(seconds: 20),
              style: TextStyle(
                  color: Colors.yellow.shade300, // Make revealed name stand out
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              curve: Curves.easeIn,
              randomString: Source.alphabets, // Use all text characters
              onFinished: () {
                // After animation finishes, we might want to reset the drawing state
                // but the StreamBuilder will handle the actual UI update from Firestore.
                // Avoid calling setState here directly if it causes issues with ReorderableListView.
                 if (mounted && (_isDrawingForSpot[item.key] ?? false)) {
                     // Small delay to ensure UI settles if needed, then let StreamBuilder refresh.
                    Future.delayed(Duration(milliseconds: 300), () {
                        if(mounted) {
                             setState(() {
                                _isDrawingForSpot[item.key] = false;
                                // _drawnSpotNameForAnimation[item.key] = null; // Cleared by StreamBuilder ideally
                            });
                        }
                    });
                 }
              },
            );
          } else {
            titleWidget = Text(titleText,
                style: TextStyle(
                    color: titleColor,
                    fontWeight: titleWeight,
                    decoration: textDecoration));
          }


          Widget listTile = ListTile(
            leading: Text(spotLabel, style: TextStyle(color: Colors.grey[400])),
            title: titleWidget,
            onTap: isCurrentlyDrawing ? null : onTapAction, // Disable tap while drawing
            trailing: trailingWidget,
          );

          Widget cardContent = Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: listTile,
          );

          // Make only PERFORMER items dismissible (and not if set over)
          if (item.isPerformer && !item.isOver) {
            return Dismissible(
              key: itemKey, // Use the stable key
              direction: DismissDirection.endToStart,
              background: Container(
                decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4)), // Match Card's default radius
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: Icon(Icons.delete_sweep, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: Text('Confirm Removal'),
                            content: Text(
                                'Remove "${item.performerName}" from spot $spotLabel?'),
                            actions: <Widget>[
                              TextButton(
                                  child: Text('Cancel'),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false)),
                              TextButton(
                                  child: Text('Remove',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true)),
                            ],
                          );
                        }) ??
                    false;
              },
              onDismissed: (direction) {
                // Optimistically update UI and then call Firestore
                //final originalItem = item; // Store for potential revert if needed
                //final originalList = List<_SpotListItem>.from(_orderedSpotList); // Backup list

                setState(() {
                  _orderedSpotList.removeWhere((i) => i.key == item.key && i.originalIndex == item.originalIndex);
                });
                _handleDismissPerformer(item.key, item.performerId, item.performerName);
              },
              child: cardContent,
            );
          } else {
            // Use a Container with the key for non-dismissible items to satisfy ReorderableListView
            return Container(key: itemKey, child: cardContent);
          }
        } catch (e) {
          // print("Error building item at index $index: $e");
          return Card(
            key: ValueKey('error_$index'),
            color: Colors.red.shade900,
            child: ListTile(
              title: Text("Error building item $index",
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(e.toString(), style: TextStyle(color: Colors.white70)),
            ),
          );
        }
      },
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final _SpotListItem item = _orderedSpotList.removeAt(oldIndex);
          _orderedSpotList.insert(newIndex, item);
          _isReordering = true; // Set flag before calling async save
        });
        _saveReorderedList(_orderedSpotList); // Will set _isReordering to false in finally
      },
    );
  }

  String _calculateSpotLabel(
      _SpotListItem item, int currentIndex, List<_SpotListItem> currentList) {
    try {
      int displayNum = 1;
      int countOfType = 0;
      for (int i = 0; i < currentList.length; i++) {
        if (currentList[i].type == item.type) {
          countOfType++;
          if (i == currentIndex) {
            displayNum = countOfType;
            break;
          }
        }
      }
      switch (item.type) {
        case SpotType.regular:
          return "$displayNum.";
        case SpotType.waitlist:
          return "W$displayNum.";
        case SpotType.bucket:
          return "B$displayNum.";
      }
    } catch (e) {
      // print("Error calculating spot label: $e");
      return "Err"; // Fallback label
    }
  }
} // End of _ShowListScreenContentState


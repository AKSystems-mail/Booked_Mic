// lib/host_screens/show_list_screen.dart

import 'dart:async';
// import 'dart:math'; // Removed unused import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Keep for FilteringTextInputFormatter
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:random_text_reveal/random_text_reveal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reorderables/reorderables.dart';
// Import Models and Providers
import 'package:myapp/providers/firestore_provider.dart';
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';
import 'package:myapp/widgets/timer_control_bar.dart';

// Define SpotCategory enum
enum SpotCategory { regular, waitlist, bucket }

// New Helper Class for List display and Reordering
class SpotDisplayData {
  final String spotKey;
  final String? userId;
  final String? name;
  final bool isOver;
  final SpotCategory category;
  final bool isEmpty;
  final UniqueKey itemKey;

  SpotDisplayData({
    required this.spotKey,
    this.userId,
    this.name,
    required this.category,
    this.isOver = false,
    this.isEmpty = false,
  }) : itemKey = UniqueKey();

  factory SpotDisplayData.emptyPlaceholder(String key, SpotCategory category) {
    return SpotDisplayData(spotKey: key, category: category, isEmpty: true);
  }
}

// --- Main Widget using MultiProvider ---
class ShowListScreen extends StatelessWidget {
  final String listId;
  const ShowListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
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
  List<SpotDisplayData> _regularSpotItems = [];
  List<SpotDisplayData> _waitlistSpotItems = [];
  List<SpotDisplayData> _bucketSpotItems = [];

  final Map<String, bool> _isDrawingForSpot = {};
  final Map<String, String?> _drawnSpotNameForAnimation = {};
  final Map<String, GlobalKey<RandomTextRevealState>> _revealControllerKeys = {};

  String _listName = "Loading...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchListName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final flashlightService = context.read<FlashlightService>();
          flashlightService.showLightPromptCallback = _showLightPromptDialog;
          flashlightService.showErrorCallback = _showErrorSnackbar;
        } catch (e) {
           print("Error setting up flashlight callbacks in initState: $e");
        }
      }
    });
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchListName() async {
    try {
      final provider = context.read<FirestoreProvider>();
      // Assuming getShow returns an object with a showName property
      final showData = await provider.getShow(widget.listId).first;
      if (mounted) {
        setState(() {
          _listName = showData.showName;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _listName = "Error Loading Name";
        });
      }
    }
  }

  void _buildDisplayLists(Map<String, dynamic> listData) {
     List<SpotDisplayData> tempRegular = [];
     List<SpotDisplayData> tempWaitlist = [];
     List<SpotDisplayData> tempBucket = [];

     Map<String, dynamic> spots = (listData['spots'] as Map<String, dynamic>?) ?? {};
     int numRegular = (listData['numberOfSpots'] as int?) ?? 0;
     int numWaitlist = (listData['numberOfWaitlistSpots'] as int?) ?? 0;
     int numBucket = (listData['numberOfBucketSpots'] as int?) ?? 0;

     // Populate Regular Spots
     for (int i = 1; i <= numRegular; i++) {
       String key = i.toString();
       if (spots.containsKey(key) && spots[key] is Map) {
         Map<String, dynamic> spotContent = spots[key];
         tempRegular.add(SpotDisplayData(
           spotKey: key,
           userId: spotContent['userId'] as String?,
           name: spotContent['name'] as String?,
           isOver: spotContent['isOver'] as bool? ?? false,
           category: SpotCategory.regular,
         ));
       } else {
         tempRegular.add(SpotDisplayData.emptyPlaceholder(key, SpotCategory.regular));
       }
     }

     // Populate Waitlist Spots
     for (int i = 1; i <= numWaitlist; i++) {
       String key = "W$i";
       if (spots.containsKey(key) && spots[key] is Map) {
         Map<String, dynamic> spotContent = spots[key];
         tempWaitlist.add(SpotDisplayData(
           spotKey: key,
           userId: spotContent['userId'] as String?,
           name: spotContent['name'] as String?,
           isOver: spotContent['isOver'] as bool? ?? false,
           category: SpotCategory.waitlist,
         ));
       } else {
         tempWaitlist.add(SpotDisplayData.emptyPlaceholder(key, SpotCategory.waitlist));
       }
     }

     // Populate Bucket Spots
     for (int i = 1; i <= numBucket; i++) {
       String key = "B$i";
        if (!_revealControllerKeys.containsKey(key)) {
            _revealControllerKeys[key] = GlobalKey<RandomTextRevealState>();
        }
       if (spots.containsKey(key) && spots[key] is Map) {
          Map<String, dynamic> spotContent = spots[key];
          tempBucket.add(SpotDisplayData(
            spotKey: key,
            userId: spotContent['userId'] as String?,
            name: spotContent['name'] as String?,
            isOver: spotContent['isOver'] as bool? ?? false,
            category: SpotCategory.bucket,
          ));
       } else {
          tempBucket.add(SpotDisplayData.emptyPlaceholder(key, SpotCategory.bucket));
       }
     }

     _regularSpotItems = tempRegular;
     _waitlistSpotItems = tempWaitlist;
     _bucketSpotItems = tempBucket;
   }

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
              content: TextField(
                 controller: minController,
                 autofocus: true,
                 keyboardType: TextInputType.number,
                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
               ),
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
              content: TextField(
                 controller: secController,
                 autofocus: true,
                 keyboardType: TextInputType.number,
                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
               ),
              actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")), TextButton(onPressed: () { int? secs = int.tryParse(secController.text); Navigator.pop(dialogContext, secs); }, child: Text("Set"))],
           );
        }
     );
      if (!mounted) return;
      if (newSeconds != null) {
       try {
           await timerService.setLightThreshold(newSeconds);
       } catch (e) {
          _showErrorSnackbar('Failed to set threshold: $e');
    }
   }
  }

  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null;
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null;
     return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
           return AlertDialog(
            title: Text('Light Performers?'),
            content: Text('The timer threshold has been reached. Would you like to flash the light?'),
            actions: <Widget>[
              TextButton(
                child: Text('Not Now'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  timerService.snoozeLightPrompt();
                },
              ),
              TextButton(
                child: Text('Yes, Flash Light'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        }
     );
  }

  void _showErrorSnackbar(String message) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName,
      bool currentStatus, String performerId) async {
      if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { return AlertDialog(title: Text('Confirm Action'), content: Text('Mark "$performerName" as set over?'),
             actions: <Widget>[ TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)), TextButton(child: Text('Yes, Set Over', style: TextStyle(color: Colors.purpleAccent)), onPressed: () => Navigator.of(dialogContext).pop(true))],
           );
        }
    );
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true, performerId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: Duration(seconds: 2)));
     } catch (e) { if (mounted) _showErrorSnackbar('Error updating status: $e'); }
     finally {
         if(mounted) setState(() => _isLoading = false);
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
                onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
              ),
            ],
         );
      }
    );

    if (!mounted) return;

    if (name != null && name.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await context.read<FirestoreProvider>().addManualNameToSpot(widget.listId, spotKey, name);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$name" to spot $spotKey.')));
        }
      } catch (e) {
         if (mounted) {
           _showErrorSnackbar('Error adding name: $e');
         }
      } finally {
         if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _promoteWaitlistToRegular(SpotDisplayData waitlistItemToPromote) async {
    if (waitlistItemToPromote.isEmpty || waitlistItemToPromote.userId == null) {
      if (mounted) _showErrorSnackbar('This waitlist spot is empty or has no user.');
      return;
    }

    String? targetRegularSpotKey;
    for (var spot in _regularSpotItems) {
      if (spot.isEmpty) {
        targetRegularSpotKey = spot.spotKey;
        break;
      }
    }

    if (targetRegularSpotKey == null) {
      if (mounted) _showErrorSnackbar('No empty regular spots available.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentReference listRef = FirebaseFirestore.instance.collection('Lists').doc(widget.listId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(listRef);
        if (!snapshot.exists) throw Exception("List does not exist!");

        Map<String, dynamic> currentSpots = Map<String, dynamic>.from(
            (snapshot.data() as Map<String, dynamic>)['spots'] as Map? ?? {});

        if (currentSpots.containsKey(targetRegularSpotKey!) && currentSpots[targetRegularSpotKey] != null) {
            throw Exception('Target regular spot $targetRegularSpotKey is no longer empty.');
        }
        if (!currentSpots.containsKey(waitlistItemToPromote.spotKey) ||
            currentSpots[waitlistItemToPromote.spotKey]?['userId'] != waitlistItemToPromote.userId) {
             throw Exception('Waitlist spot ${waitlistItemToPromote.spotKey} data changed unexpectedly.');
        }

        currentSpots[targetRegularSpotKey] = {
          'userId': waitlistItemToPromote.userId,
          'name': waitlistItemToPromote.name,
          'isOver': false,
        };

        currentSpots.remove(waitlistItemToPromote.spotKey);

        transaction.update(listRef, {'spots': currentSpots});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${waitlistItemToPromote.name ?? 'Performer'} moved to Regular Spot $targetRegularSpotKey.')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error promoting: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBucketDraw(String spotKey) async {
    if (!mounted || (_isDrawingForSpot[spotKey] ?? false) || _isLoading) return;

    if (!_revealControllerKeys.containsKey(spotKey)) {
      _revealControllerKeys[spotKey] = GlobalKey<RandomTextRevealState>();
    }

    setState(() {
      _isDrawingForSpot[spotKey] = true;
      _drawnSpotNameForAnimation[spotKey] = "Picking...";
      _isLoading = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    _revealControllerKeys[spotKey]?.currentState?.play();

    Map<String, dynamic>? drawnSpotData;
    String? errorMsg;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context before await

    try {
      final firestoreProvider = context.read<FirestoreProvider>();
      drawnSpotData = await firestoreProvider.drawAndAssignBucketSpot(widget.listId, spotKey);

      if (mounted) {
        if (drawnSpotData != null && drawnSpotData['name'] != null) {
          final drawnName = drawnSpotData['name'] as String;
          setState(() {
            _drawnSpotNameForAnimation[spotKey] = drawnName;
          });
          await WidgetsBinding.instance.endOfFrame;
           _revealControllerKeys[spotKey]?.currentState?.play();
           await Future.delayed(const Duration(seconds: 2, milliseconds: 300));
        } else {
           errorMsg = 'Could not draw from bucket (it might be empty or data error).';
        }
      }
    } catch (e) {
       errorMsg = 'Error drawing from bucket: ${e.toString()}';
    } finally {
       if (mounted) {
          if (errorMsg != null) {
             scaffoldMessenger.showSnackBar( // Use captured messenger
               SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange),
             );
          }
          setState(() {
            _isDrawingForSpot[spotKey] = false;
            _isLoading = false;
          });
       }
    }
  }

  Future<void> _handleDismissPerformer(
      String spotKey, String performerId, String performerName) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context
    setState(() => _isLoading = true);
    try {
      await context
          .read<FirestoreProvider>()
          .removePerformerFromSpot(widget.listId, spotKey);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar( // Use captured messenger
          SnackBar(content: Text('Error removing performer: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onReorderRegularSpots(int oldIndex, int newIndex) {
    ScaffoldMessenger.of(context); // Capture context
    setState(() {
      _isLoading = true;
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final SpotDisplayData item = _regularSpotItems.removeAt(oldIndex);
      _regularSpotItems.insert(newIndex, item);

      _updateFirestoreAfterRegularReorder().catchError((e) {
         print("Firestore reorder failed, UI might be out of sync briefly.");
         // Error snackbar is shown inside _updateFirestoreAfterRegularReorder
      }).whenComplete(() {
        if (mounted) {
           // Optionally show success snackbar here if needed
          // scaffoldMessenger.showSnackBar(
          //   const SnackBar(content: Text('Regular spot order updated.')),
          // );
          setState(() => _isLoading = false);
        }
      });
    });
  }

  Future<void> _updateFirestoreAfterRegularReorder() async {
    Map<String, dynamic> newSpotsMapForFirestore = {};
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture context

    try {
      DocumentSnapshot listSnapshot = await FirebaseFirestore.instance.collection('Lists').doc(widget.listId).get();
      if (!listSnapshot.exists) throw Exception("List not found for reorder.");

      Map<String, dynamic> existingFullSpotsMap = Map<String, dynamic>.from(
          (listSnapshot.data() as Map<String, dynamic>)['spots'] as Map? ?? {});

      existingFullSpotsMap.forEach((key, value) {
        if (key.startsWith('W') || key.startsWith('B')) {
          newSpotsMapForFirestore[key] = value;
        }
      });

    } catch (e) {
       if (mounted) {
         scaffoldMessenger.showSnackBar( // Use captured messenger
           SnackBar(content: Text('Error preparing update: ${e.toString()}')),
         );
       }
       // No need to set isLoading=false here, caller's whenComplete handles it
       rethrow; // Rethrow to trigger catchError in caller
    }

    for (int i = 0; i < _regularSpotItems.length; i++) {
      final spotItem = _regularSpotItems[i];
      if (!spotItem.isEmpty && spotItem.userId != null) {
        String newRegularKey = (i + 1).toString();
        newSpotsMapForFirestore[newRegularKey] = {
          'userId': spotItem.userId,
          'name': spotItem.name,
          'isOver': spotItem.isOver,
        };
      }
    }

    try {
      // final provider = context.read<FirestoreProvider>(); // Removed unused variable
      await context.read<FirestoreProvider>().saveReorderedSpots(widget.listId, newSpotsMapForFirestore);
    } catch (e) {
      print("Error reordering regular spots in Firestore: $e");
      if (mounted) {
        scaffoldMessenger.showSnackBar( // Use captured messenger
          SnackBar(content: Text('Error saving order: ${e.toString()}')),
        );
      }
      rethrow; // Use rethrow
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
    );
  }

  Widget _buildSpotTile(SpotDisplayData item, {bool isRegular = false, int? displayIndex}) {
    String spotLabel = isRegular ? '${displayIndex! + 1}.' : '${item.spotKey}.';

    String titleText;
    Color titleColor; // Define color variable
    FontWeight titleWeight = FontWeight.normal;
    TextDecoration textDecoration = TextDecoration.none;
    FontStyle titleFontStyle = FontStyle.normal;

    if (item.isEmpty) {
      titleText = 'Available';
      titleColor = Colors.green.shade400; // Lighter grey for dark theme
      titleFontStyle = FontStyle.italic;
    } else {
      titleText = item.name ?? 'Error: No Name';
      titleColor = item.isOver ? Colors.grey.shade500 : Colors.blue.shade200; // Brighter blue for name
      titleWeight = FontWeight.w500;
      textDecoration = item.isOver ? TextDecoration.lineThrough : TextDecoration.none;
    }

    Widget? trailingWidget;
    if (item.category == SpotCategory.waitlist && !item.isEmpty && !item.isOver) {
      trailingWidget = FadeIn(
        child: IconButton(
          icon: Icon(Icons.publish_outlined, color: Colors.green.shade300), // Brighter green
          tooltip: 'Move to Regular Spot',
          onPressed: _isLoading ? null : () => _promoteWaitlistToRegular(item),
        ),
      );
    } else if (isRegular && !item.isEmpty && !item.isOver) {
      trailingWidget = ReorderableDragStartListener(
        index: displayIndex!,
        child: Icon(Icons.drag_handle, color: Colors.grey.shade500), // Keep subtle drag handle
      );
    }

    VoidCallback? onTapAction;
    if (item.category == SpotCategory.regular || item.category == SpotCategory.waitlist) {
      if (item.isEmpty) {
        onTapAction = _isLoading ? null : () => _showAddNameDialog(item.spotKey);
      } else if (!item.isOver) {
        onTapAction = _isLoading ? null : () => _showSetOverDialog(item.spotKey, item.name ?? '?', item.isOver, item.userId ?? '');
      }
    } else if (item.category == SpotCategory.bucket) {
      if (item.isEmpty) {
        onTapAction = _isLoading ? null : () => _handleBucketDraw(item.spotKey);
      } else if (!item.isOver) {
        onTapAction = _isLoading ? null : () => _showSetOverDialog(item.spotKey, item.name ?? '?', item.isOver, item.userId ?? '');
      }
    }

    Widget titleWidget;
    bool isCurrentlyDrawing = _isDrawingForSpot[item.spotKey] ?? false;

    if (item.category == SpotCategory.bucket && item.isEmpty && isCurrentlyDrawing) {
      if (!_revealControllerKeys.containsKey(item.spotKey)) {
        _revealControllerKeys[item.spotKey] = GlobalKey<RandomTextRevealState>();
      }
      titleWidget = RandomTextReveal(
        key: _revealControllerKeys[item.spotKey],
        text: _drawnSpotNameForAnimation[item.spotKey] ?? "Picking...",
        duration: const Duration(seconds: 2), // Adjusted duration from previous version
        style: TextStyle(
            color: Colors.yellow.shade300, // Standout color for revealed name
            fontWeight: FontWeight.bold,
            fontSize: 16),
        curve: Curves.fastOutSlowIn,
        randomString: "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz",
        onFinished: () {
          if (mounted && (_isDrawingForSpot[item.spotKey] ?? false)) {
            Future.delayed(Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isDrawingForSpot[item.spotKey] = false;
                });
              }
            });
          }
        },
      );
      trailingWidget = SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.secondary), // Use theme color
      );
    } else if (item.category == SpotCategory.bucket && item.isEmpty && !isCurrentlyDrawing) {
      titleText = '(Tap to Draw from Bucket)';
      titleColor = Colors.teal.shade300; // Distinct color for bucket
      titleFontStyle = FontStyle.italic;
      titleWidget = Text(titleText, style: TextStyle(color: titleColor, fontStyle: titleFontStyle));
    } else {
      titleWidget = Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration, fontStyle: titleFontStyle));
    }

    Widget listTile = ListTile(
      leading: Text(
        spotLabel,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade400), // Lighter for dark theme
      ),
      title: titleWidget,
      trailing: trailingWidget,
      onTap: (isCurrentlyDrawing || _isLoading) ? null : onTapAction,
    );

    Widget card = Card(
      // key: item.itemKey, // Key is now on the Dismissible or Container wrapper
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      // Card color will be inherited from Theme(data: ThemeData.dark().copyWith(cardColor: ...))
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: listTile,
    );

    // Logic for Dismissible (copied from your provided code, assuming it's what you want)
    if ((item.category == SpotCategory.regular || item.category == SpotCategory.waitlist) &&
        !item.isEmpty &&
        !item.isOver &&
        item.userId != null) {
      return Dismissible(
        key: item.itemKey, // Use the unique key from SpotDisplayData
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
              color: Colors.red.shade700, // Keep dismiss color
              borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      'Remove "${item.name ?? 'Performer'}" from spot $spotLabel?'),
                  actions: <Widget>[
                    TextButton(
                        child: Text('Cancel'),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false)),
                    TextButton(
                        child: Text('Remove',
                            style: TextStyle(color: Colors.red.shade300)), // Lighter red for dark theme
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true)),
                  ],
                );
              }) ??
              false;
        },
        onDismissed: (direction) {
          _handleDismissPerformer(item.spotKey, item.userId!, item.name ?? 'Performer');
        },
        child: card,
      );
    } else {
      // Important: ReorderableListView children MUST have keys.
      // If not dismissible, wrap the card in a Container with the key.
      return Container(key: item.itemKey, child: card);
    }
  }


  @override
  Widget build(BuildContext context) {
    // final Color appBarColor = Colors.blue.shade600; // Will be overridden by theme
    final timerService = context.watch<TimerService>();

    Color dynamicAppBarColor = Colors.blue.shade400; // Default if not dark theme
    if (Theme.of(context).brightness == Brightness.dark) {
        dynamicAppBarColor = Colors.grey[850]!; // Dark AppBar for dark theme
        if (timerService.isTimerRunning || timerService.isPaused) {
            dynamicAppBarColor = Colors.indigo.shade800; // Darker Indigo for active timer in dark theme
        }
    } else { // Light Theme
        if (timerService.isTimerRunning || timerService.isPaused) {
            dynamicAppBarColor = Colors.indigo.shade700;
        }
    }


    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.grey[900], // Darker scaffold
        appBarTheme: AppBarTheme(
          backgroundColor: dynamicAppBarColor, // Use dynamic color
          elevation: 1,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardColor: Colors.grey[800], // Darker cards
        dialogBackgroundColor: Colors.grey[800],
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.grey[300], // Lighter text for body
          displayColor: Colors.white,   // Lighter text for display
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blue.shade300) // Brighter button text
        ),
        iconTheme: IconThemeData(color: Colors.grey[400]), // Default icon color
        primaryColor: Colors.blue.shade300, // Brighter primary
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade300,
          secondary: Colors.teal.shade300, // Brighter secondary
          surface: Colors.grey[800]!,
          background: Colors.grey[900]!,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
          error: Colors.red.shade400,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.blue.shade300
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[700],
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        // Add other theme properties as needed
      ),
      child: Scaffold(
        appBar: AppBar(
          // title: Text(_listName), // _listName is already handled by StreamBuilder in your previous code
          // Use StreamBuilder for title as in your provided code if that's preferred
           title: StreamBuilder<DocumentSnapshot>( // Assuming getShow returns DocumentSnapshot now
            stream: FirebaseFirestore.instance.collection('Lists').doc(widget.listId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Text('Loading List...');
              } else if (snapshot.hasError) {
                return Text('Error Loading Title');
              } else if (!snapshot.hasData || !snapshot.data!.exists) {
                return Text('List Not Found');
              } else {
                // Assuming 'listName' is the field in your 'Lists' document
                final listData = snapshot.data!.data() as Map<String, dynamic>;
                _listName = listData['listName'] ?? 'Unnamed List';
                return Text(_listName);
              }
            },
          ),
          // backgroundColor: currentAppBarColor, // Handled by Theme's appBarTheme
          // elevation: 1, // Handled by Theme
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0))),
              )
          ],
          bottom: TimerControlBar(
            backgroundColor: dynamicAppBarColor, // Pass dynamic color
            onSetTotalDialog: _setTotalTimerDialog,
            onSetThresholdDialog: _setThresholdDialog,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>( // Changed from Show to DocumentSnapshot for direct use
          stream: FirebaseFirestore.instance.collection('Lists').doc(widget.listId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
               return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading list data: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('List not found or has been deleted.'));
            }

            Map<String, dynamic> listData = snapshot.data!.data() as Map<String, dynamic>;
            // Only rebuild display lists if not currently loading from a user action
            // This prevents the list from flickering during Firestore save operations
            // if the stream emits the old data briefly before the new data.
            if (!_isLoading) {
               _buildDisplayLists(listData);
            }

            bool noRegular = _regularSpotItems.isEmpty;
            bool noWaitlist = _waitlistSpotItems.isEmpty;
            bool noBucket = _bucketSpotItems.isEmpty;

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildSectionHeader('Regular Spots')),
                if (noRegular)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: Center(child: Text('No regular spots defined.', style: TextStyle(color: Colors.grey.shade500))), // Adjusted color
                        ),
                      )
                    else
                      ReorderableSliverList(
                        delegate: ReorderableSliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final item = _regularSpotItems[index];
                            return _buildSpotTile(item, isRegular: true, displayIndex: index);
                          },
                          childCount: _regularSpotItems.length,
                        ),
                        onReorder: _isLoading ? (int o, int n) {} : _onReorderRegularSpots,
                      ),

                    SliverToBoxAdapter(child: _buildSectionHeader('Waitlist Spots')),
                    if (noWaitlist)
                       SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: Center(child: Text('No waitlist spots defined.', style: TextStyle(color: Colors.grey.shade500))), // Adjusted color
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final item = _waitlistSpotItems[index];
                            return _buildSpotTile(item);
                          },
                          childCount: _waitlistSpotItems.length,
                        ),
                      ),

                     SliverToBoxAdapter(child: _buildSectionHeader('Bucket Spots')),
                     if (noBucket)
                       SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: Center(child: Text('No bucket spots defined.', style: TextStyle(color: Colors.grey.shade500))), // Adjusted color
                        ),
                      )
                     else
                       SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            final item = _bucketSpotItems[index];
                            return _buildSpotTile(item);
                          },
                          childCount: _bucketSpotItems.length,
                        ),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
          ),
        );
      }
    }
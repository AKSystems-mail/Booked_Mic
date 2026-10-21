// lib/host_screens/show_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/booked_mic_loading.dart';
import 'package:animate_do/animate_do.dart';
import 'package:random_text_reveal/random_text_reveal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // <-- ADDED IMPORT

import '../providers/firestore_provider.dart';
import '../providers/timer_service.dart';
import '../providers/flashlight_service.dart';
import '../widgets/timer_control_bar.dart';

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
    return MultiProvider(
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
  
  bool _isReordering = false;
  bool _hasPromptedLightForCurrentSession = false; // Flag to prevent duplicate dialogs in the same tick

  final Map<String, bool> _isDrawingForSpot = {};
  final Map<String, String?> _drawnSpotNameForAnimation = {};
  final Map<String, GlobalKey<RandomTextRevealState>> _revealControllerKeys = {};

  String _listName = "Loading...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchListName();

    // 1. Prevent the screen from sleeping while on this dashboard
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint("Wakelock error: $e");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final timerService = context.read<TimerService>();
        final flashlightService = context.read<FlashlightService>();

        // 2. Attach a fallback UI-level listener to the TimerService
        timerService.addListener(_handleTimerTick);

        try {
          flashlightService.showLightPromptCallback = _showLightPromptDialog;
          flashlightService.showErrorCallback = _showErrorSnackbar;
        } catch (e) { // Ignore
        }
      }
    });
  }

  @override
  @mustCallSuper
  void dispose() {
    // 3. Disable the wakelock when exiting the screen to save battery
    try {
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("Wakelock error: $e");
    }

    // Remove the timer listener
    try {
      context.read<TimerService>().removeListener(_handleTimerTick);
    } catch (e) {}

    _isReordering = false;
    super.dispose();
  }

  // Fallback to guarantee the prompt dialog triggers on the exact second
  void _handleTimerTick() {
    if (!mounted) return;
    final timerService = context.read<TimerService>();

    // Reset prompt flag if the timer stops or resets
    if (!timerService.isTimerRunning) {
      _hasPromptedLightForCurrentSession = false;
      return;
    }

    // Trigger dialog when remaining time hits the threshold
    if (timerService.isTimerRunning &&
        timerService.remainingSecondsNotifier.value == timerService.lightThresholdSeconds &&
        !_hasPromptedLightForCurrentSession) {
      _hasPromptedLightForCurrentSession = true;
      _triggerThresholdLight();
    }
  }

  Future<void> _triggerThresholdLight() async {
    final shouldFlash = await _showLightPromptDialog();
    if (shouldFlash == true && mounted) {
      try {
        final flashlightService = context.read<FlashlightService>();
        await flashlightService.toggleFlashlight();
      } catch (e) {
        _showErrorSnackbar('Failed to flash light: $e');
      }
    }
  }

  Future<void> _fetchListName() async {
    try {
      final provider = context.read<FirestoreProvider>();
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

     for (int i = 1; i <= numRegular; i++) {
       String key = i.toString();
       if (spots.containsKey(key) && spots[key] is Map) {
         Map<String, dynamic> spotContent = spots[key];
         if (spotContent.isEmpty) {
           tempRegular.add(SpotDisplayData.emptyPlaceholder(key, SpotCategory.regular));
         } else {
           tempRegular.add(SpotDisplayData(
             spotKey: key,
             userId: spotContent['userId'] as String?,
             name: spotContent['name'] as String?,
             isOver: spotContent['isOver'] as bool? ?? false,
             category: SpotCategory.regular,
           ));
         }
       } else {
         tempRegular.add(SpotDisplayData.emptyPlaceholder(key, SpotCategory.regular));
       }
     }

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

  Future<void> _showQrDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(child: Text(_listName, style: const TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: QrImageView(
                data: widget.listId,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Scan to Join List', style: TextStyle(color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

Future<void> _showTimerSettingsDialog() async {
  if (!mounted) return;
  final timerService = context.read<TimerService>();
  int dialogMinutes = timerService.totalSeconds ~/ 60;
  if (dialogMinutes == 0 && timerService.totalSeconds > 0) {
    dialogMinutes = 1;
  } else if (dialogMinutes == 0) {
    dialogMinutes = 5;
  }
  int dialogThresholdSeconds = timerService.lightThresholdSeconds;
  if (dialogThresholdSeconds <= 0) {
    dialogThresholdSeconds = 30;
  }
  // Cap threshold to current set length on dialog open
  final int maxOnOpen = dialogMinutes * 60;
  if (dialogThresholdSeconds > maxOnOpen) {
    dialogThresholdSeconds = maxOnOpen;
  }

  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Timer Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Set Length', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '$dialogMinutes min',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                Slider(
                  value: dialogMinutes.toDouble(),
                  min: 1,
                  max: 90,
                  divisions: 89,
                  label: dialogMinutes.toString(),
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  onChanged: (double value) {
                    setDialogState(() {
                      dialogMinutes = value.round();
                      final int maxThreshold = dialogMinutes * 60;
                      if (dialogThresholdSeconds > maxThreshold) {
                        dialogThresholdSeconds = maxThreshold;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text('Getting the light at...', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  dialogThresholdSeconds >= 60
                      ? '${dialogThresholdSeconds ~/ 60} min ${dialogThresholdSeconds % 60} s'
                      : '$dialogThresholdSeconds s',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                Slider(
                  value: dialogThresholdSeconds.toDouble(),
                  min: 5,
                  max: (dialogMinutes * 60).toDouble(),
                  divisions: dialogMinutes * 12 - 1,
                  label: dialogThresholdSeconds >= 60
                      ? '${dialogThresholdSeconds ~/ 60} min ${dialogThresholdSeconds % 60} s'
                      : '${dialogThresholdSeconds}s',
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  onChanged: (double value) {
                    setDialogState(() {
                      dialogThresholdSeconds = (value / 5).round() * 5;
                      if (dialogThresholdSeconds < 5) dialogThresholdSeconds = 5;
                      final int maxThreshold = dialogMinutes * 60;
                      if (dialogThresholdSeconds > maxThreshold) dialogThresholdSeconds = maxThreshold;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save')),
            ],
          );
        },
      );
    },
  );

  if (saved == true) {
    await timerService.setTotalSeconds(dialogMinutes * 60);
    await timerService.setLightThreshold(dialogThresholdSeconds);
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
            title: const Text('Light Performers?'),
            content: const Text('The timer threshold has been reached. Would you like to flash the light?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Not Now'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                  timerService.snoozeLightPrompt();
                },
              ),
              TextButton(
                child: const Text('Yes, Flash Light'),
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
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { return AlertDialog(title: const Text('Confirm Action'), content: Text('Mark "$performerName" as set over?'),
             actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)), TextButton(child: const Text('Yes, Set Over', style: TextStyle(color: Colors.purpleAccent)), onPressed: () => Navigator.of(dialogContext).pop(true))],
           );
        }
    );
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true, performerId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$performerName" marked as over.'), duration: const Duration(seconds: 2)));
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
            title: const Text('Add Performer Name'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Performer Name'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text('Add'),
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
         if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

Future<void> _promoteWaitlistToRegular(SpotDisplayData waitlistItemToPromote) async {
  if (waitlistItemToPromote.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This waitlist spot is empty.')),
      );
    }
    return;
  }
  if (waitlistItemToPromote.name == null || waitlistItemToPromote.name!.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This waitlist spot has no name to promote.')),
        );
      }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No empty regular spots available.')),
      );
    }
    return;
  }

  setState(() => _isLoading = true);

  try {
    DocumentReference listRef = FirebaseFirestore.instance.collection('Lists').doc(widget.listId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(listRef);
      if (!snapshot.exists) {
        throw Exception("List does not exist!");
      }
      Map<String, dynamic> currentSpots = Map<String, dynamic>.from(
          (snapshot.data() as Map<String, dynamic>)['spots'] as Map? ?? {});

      Map<String, dynamic> newRegularSpotData = {
        'name': waitlistItemToPromote.name!,
        'isOver': false,
      };
      if (waitlistItemToPromote.userId != null) {
        newRegularSpotData['userId'] = waitlistItemToPromote.userId;
      }

      currentSpots[targetRegularSpotKey!] = newRegularSpotData;
      currentSpots.remove(waitlistItemToPromote.spotKey);

      Map<String, dynamic> updatePayload = {
        'spots': currentSpots,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (waitlistItemToPromote.userId != null) {
        updatePayload['signedUpUserIds'] = FieldValue.arrayUnion([waitlistItemToPromote.userId!]);
      }

      transaction.update(listRef, updatePayload);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${waitlistItemToPromote.name ?? 'Performer'} moved to Regular Spot $targetRegularSpotKey.')),
      );
    }
  } catch (e) {
    debugPrint("Error promoting performer: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error promoting: ${e.toString()}')),
      );
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
    if (!mounted) return;
    _revealControllerKeys[spotKey]?.currentState?.play();

    Map<String, dynamic>? drawnSpotData;
    String? errorMsg;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
    if (!mounted) return;
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
             scaffoldMessenger.showSnackBar(
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await context
          .read<FirestoreProvider>()
          .removePerformerFromSpot(widget.listId, spotKey);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error removing performer: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

void _onReorderRegularSpots(int oldIndex, int newIndex) {
  if (_isLoading || _isReordering) return;

  setState(() {
    _isReordering = true;
  });

  if (oldIndex < newIndex) {
    newIndex -= 1;
  }
  final SpotDisplayData item = _regularSpotItems.removeAt(oldIndex);
  _regularSpotItems.insert(newIndex, item);

  setState(() {
    _isLoading = true;
  });

  _updateFirestoreAfterRegularReorder().catchError((e) {
    if (mounted) {
      final SpotDisplayData revertedItem = _regularSpotItems.removeAt(newIndex);
      _regularSpotItems.insert(oldIndex, revertedItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save order. Please try again.'), 
          backgroundColor: Colors.red
        ),
      );
    }
  }).whenComplete(() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isReordering = false;
      });
    }
  });
}


Future<void> _updateFirestoreAfterRegularReorder() async {
  try {
    DocumentSnapshot listSnapshot = await FirebaseFirestore.instance
        .collection('Lists')
        .doc(widget.listId)
        .get();
    
    if (!listSnapshot.exists) {
      throw Exception("List not found for reorder.");
    }
    
    Map<String, dynamic> existingData = listSnapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> existingSpots = Map<String, dynamic>.from(
        existingData['spots'] as Map? ?? {});

    Map<String, dynamic> newSpotsMap = {};
    
    existingSpots.forEach((key, value) {
      if (key.startsWith('W') || key.startsWith('B')) {
        newSpotsMap[key] = value;
      }
    });

    for (int i = 0; i < _regularSpotItems.length; i++) {
      final spotItem = _regularSpotItems[i];
      String newRegularKey = (i + 1).toString();

      if (!spotItem.isEmpty && spotItem.name != null && spotItem.name!.isNotEmpty) {
        Map<String, dynamic> spotDataToSave = {
          'name': spotItem.name,
          'isOver': spotItem.isOver,
        };
        if (spotItem.userId != null) {
          spotDataToSave['userId'] = spotItem.userId;
        }
        newSpotsMap[newRegularKey] = spotDataToSave;
      }
      // Empty slots are intentionally NOT written: an absent key already
      // renders as "available" in every client. Writing `{}` here was the
      // source of the recurring empty-spot bug (reorder re-dirtied the map).
    }

    await FirebaseFirestore.instance
        .collection('Lists')
        .doc(widget.listId)
        .update({
      'spots': newSpotsMap,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint("Regular spots reordered successfully in Firestore.");
    
  } catch (e) {
    debugPrint("Error reordering regular spots in Firestore: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    rethrow;
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
    Color titleColor;
    FontWeight titleWeight = FontWeight.normal;
    TextDecoration textDecoration = TextDecoration.none;
    FontStyle titleFontStyle = FontStyle.normal;

    if (item.isEmpty) {
      titleText = 'Available';
      titleColor = Colors.green.shade400;
      titleFontStyle = FontStyle.italic;
    } else {
      titleText = item.name ?? 'Error: No Name';
      titleColor = item.isOver ? Colors.grey.shade500 : Colors.blue.shade200;
      titleWeight = FontWeight.w500;
      textDecoration = item.isOver ? TextDecoration.lineThrough : TextDecoration.none;
    }

    Widget? trailingWidget;
    if (item.category == SpotCategory.waitlist && !item.isEmpty && !item.isOver) {
      trailingWidget = FadeIn(
        child: IconButton(
          icon: Icon(Icons.publish_outlined, color: Colors.green.shade300),
          tooltip: 'Move to Regular Spot',
          onPressed: _isLoading ? null : () => _promoteWaitlistToRegular(item),
        ),
      );
    } else if (isRegular && !item.isEmpty && !item.isOver) {
      trailingWidget = ReorderableDragStartListener(
        index: displayIndex!,
        child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
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
        text: _drawnSpotNameForAnimation[item.spotKey] ?? "...",
        duration: const Duration(seconds: 2),
        style: TextStyle(
            color: Colors.yellow.shade300,
            fontWeight: FontWeight.bold,
            fontSize: 16),
        curve: Curves.fastOutSlowIn,
        randomString: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
        onFinished: () {
          if (mounted && (_isDrawingForSpot[item.spotKey] ?? false)) {
            Future.delayed(const Duration(milliseconds: 3000), () {
              if (mounted) {
                setState(() {
                  _isDrawingForSpot[item.spotKey] = false;
                });
              }
            });
          }
        },
      );
      trailingWidget = const BookedMicLoading(compact: true);
    } else if (item.category == SpotCategory.bucket && item.isEmpty && !isCurrentlyDrawing) {
      titleText = '(Tap to Draw from Bucket)';
      titleColor = Colors.teal.shade300;
      titleFontStyle = FontStyle.italic;
      titleWidget = Text(titleText, style: TextStyle(color: titleColor, fontStyle: titleFontStyle));
    } else {
      titleWidget = Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration, fontStyle: titleFontStyle));
    }

    Widget listTile = ListTile(
      leading: Text(
        spotLabel,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
      ),
      title: titleWidget,
      trailing: trailingWidget,
      onTap: (isCurrentlyDrawing || _isLoading) ? null : onTapAction,
    );

    Widget card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: listTile,
    );

      if (!item.isEmpty && !item.isOver && (item.name != null && item.name!.isNotEmpty)) {

      return Dismissible(
        key: item.itemKey,
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerRight,
          child: const Icon(Icons.delete_sweep, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Confirm Removal'),
                  content: Text(
                      'Remove "${item.name ?? 'Performer'}" from spot $spotLabel?'),
                  actions: <Widget>[
                    TextButton(
                        child: const Text('Cancel'),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false)),
                    TextButton(
                        child: const Text('Remove',
                            style: TextStyle(color: Colors.red)),
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
      return Container(key: item.itemKey, child: card);
    }
  }


  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();

    Color dynamicAppBarColor = Colors.blue.shade400;
    if (Theme.of(context).brightness == Brightness.dark) {
        dynamicAppBarColor = Colors.grey[850]!;
        if (timerService.isTimerRunning || timerService.isPaused) {
            dynamicAppBarColor = Colors.indigo.shade800;
        }
    } else {
        if (timerService.isTimerRunning || timerService.isPaused) {
            dynamicAppBarColor = Colors.indigo.shade700;
        }
    }


    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: dynamicAppBarColor,
          elevation: 1,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardColor: Colors.grey[800],
        dialogTheme: DialogThemeData(backgroundColor: Colors.grey[800]),
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.grey[300],
          displayColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.blue.shade300)
        ),
        iconTheme: const IconThemeData(color: Colors.grey),
        primaryColor: Colors.blue.shade300,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue.shade300,
          secondary: Colors.teal.shade300,
          surface: Colors.grey[800]!,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.white,
          error: Colors.red.shade400,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.blue.shade300
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey[700],
          contentTextStyle: const TextStyle(color: Colors.white),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
           title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Lists').doc(widget.listId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Text('Loading List...');
              } else if (snapshot.hasError) {
                return const Text('Error Loading Title');
              } else if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text('List Not Found');
              } else {
                final listData = snapshot.data!.data() as Map<String, dynamic>;
                _listName = listData['listName'] ?? 'Unnamed List';
                return Text(_listName);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Show QR Code',
              onPressed: _showQrDialog,
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(child: BookedMicLoading(compact: true, compactSize: 20)),
              )
          ],
          bottom: TimerControlBar(
            backgroundColor: dynamicAppBarColor,
            onTapDigits: _showTimerSettingsDialog,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('Lists').doc(widget.listId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
               return const BookedMicLoading();
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading list data: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('List not found or has been deleted.'));
            }

            Map<String, dynamic> listData = snapshot.data!.data() as Map<String, dynamic>;
    if (!_isLoading && !_isReordering) {
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
                    child: Center(child: Text('No regular spots created.', style: TextStyle(color: Colors.grey.shade500))),
                  ),
                )
              else
                SliverReorderableList(
                  itemBuilder: (BuildContext context, int index) {
                    final item = _regularSpotItems[index];
                    return _buildSpotTile(item, isRegular: true, displayIndex: index);
                  },
                  itemCount: _regularSpotItems.length,
                  onReorder: _isLoading ? (int o, int n) {} : _onReorderRegularSpots,
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: child,
                    );
                  },
                ),

                    SliverToBoxAdapter(child: _buildSectionHeader('Waitlist Spots')),
                    if (noWaitlist)
                       SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                          child: Center(child: Text('No waitlist spots created.', style: TextStyle(color: Colors.grey.shade500))),
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
                          child: Center(child: Text('No bucket spots created.', style: TextStyle(color: Colors.grey.shade500))),
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
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                );
              },
            ),
          ),
        );
  }
}
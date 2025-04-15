import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

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
class ShowListScreen extends StatelessWidget {
  final String listId;
  const ShowListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FirestoreProvider>(
      create: (_) => FirestoreProvider(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TimerService>(create: (_) => TimerService(listId: listId)),
          ChangeNotifierProxyProvider<TimerService, FlashlightService>(
            create: (context) => FlashlightService(listId: listId, timerService: Provider.of<TimerService>(context, listen: false)),
            update: (context, timerService, previousFlashlightService) {
               final flashlight = previousFlashlightService ?? FlashlightService(listId: listId, timerService: timerService);
               return flashlight;
            }
          ),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
         try {
            final flashlightService = context.read<FlashlightService>();
            flashlightService.showLightPromptCallback = _showLightPromptDialog;
            flashlightService.showErrorCallback = _showErrorSnackbar;
         } catch (e) { }
      }
    });
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
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
              content: TextField(controller: minController, autofocus: true,),
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
              content: TextField(controller: secController, autofocus: true,),
              actions: [ TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel")), TextButton(onPressed: () { int? secs = int.tryParse(secController.text); Navigator.pop(dialogContext, secs); }, child: Text("Set"))],
           );
        }
     );
     if (newSeconds != null) {
       bool success = await timerService.setLightThreshold(newSeconds);
       if (!success && mounted) { _showErrorSnackbar('Error setting threshold.'); }
       else if (success && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Threshold set successfully.'))); }
     }
  }

  Future<bool?> _showLightPromptDialog() async {
     if (!mounted) return null;
     final timerService = context.read<TimerService>();
     if (!timerService.isTimerRunning) return null;
     return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); }
     );
  }

  void _showErrorSnackbar(String message) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _showSetOverDialog(String spotKey, String performerName, bool currentStatus) async {
    if (!mounted || currentStatus) return;
    final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI ... */ ); });
    if (confirm == true) {
      if (!mounted) return;
      try { await context.read<FirestoreProvider>().setSpotOver(widget.listId, spotKey, true, ''); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Spot marked as over.'))); } }
      catch (e) { _showErrorSnackbar('Error marking spot as over.'); }
    }
  }

  Future<void> _showAddNameDialog(String spotKey) async {
    if (!mounted) return;
    TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>( context: context, builder: (BuildContext dialogContext) { return AlertDialog( /* ... Dialog UI using nameController ... */ ); });
    if (name != null && name.isNotEmpty) {
      if (!mounted) return;
      try { await context.read<FirestoreProvider>().addManualNameToSpot(widget.listId, spotKey, name); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Name added to spot.'))); } }
      catch (e) { _showErrorSnackbar('Error adding name to spot.'); }
    }
  }

  Future<void> _handleDismissPerformer(String spotKey, String performerId) async {
    if (!mounted) return;
    try { await context.read<FirestoreProvider>().removePerformerFromSpot(widget.listId, spotKey); }
    catch (e) { _showErrorSnackbar('Error removing performer from spot.'); }
  }

    List<_SpotListItem> _createOrderedList(Map<String, dynamic> spotsMap, int totalRegular, int totalWaitlist, int totalBucket) {
    List<_SpotListItem> items = [];
    int index = 0;
    void addItem(String key, dynamic data, SpotType type) {
      items.add(_SpotListItem(key: key, type: type, data: data, originalIndex: index++));
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

    return Theme(
      data: ThemeData.dark().copyWith(
        // Add your dark theme overrides here
      ),
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<Show>(
            stream: firestoreProvider.getShow(widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('Loading...');
              } else if (snapshot.hasError) {
                return Text('Error');
              } else if (!snapshot.hasData || snapshot.data == null) {
                return Text('List not found');
              } else {
                return Text(snapshot.data!.title);
              }
            },
          ),
          bottom: TimerControlBar(
            backgroundColor: Colors.blue.shade400,
            onSetTotalDialog: _setTotalTimerDialog,
            onSetThresholdDialog: _setThresholdDialog,
          ),
        ),
        body: StreamBuilder<Show>(
          stream: firestoreProvider.getShow(widget.listId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading list.'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text('List not found.'));
            } else {
              final showData = snapshot.data!;
              if (!_isReordering) {
                _orderedSpotList = _createOrderedList(
                  showData.spots,
                  showData.numberOfSpots,
                  showData.numberOfWaitlistSpots,
                  showData.numberOfBucketSpots,
                );
              }
              if (_orderedSpotList.isEmpty) {
                return Center(child: Text("This list currently has no spots defined."));
              }
              return _buildListWidgetContent(context, _orderedSpotList);
            }
          },
        ),
      ),
    );
  }

  Widget _buildListWidgetContent(BuildContext context, List<_SpotListItem> spotItems) {
    return ReorderableListView.builder(
      padding: EdgeInsets.only(bottom: 80, top: 8),
      itemCount: spotItems.length,
      itemBuilder: (context, index) {
        try {
          final item = spotItems[index];
          final itemKey = ValueKey('${item.key}_${item.originalIndex}');
          String titleText = 'Available';
          Color titleColor = Colors.green.shade300;
          FontWeight titleWeight = FontWeight.normal;
          TextDecoration textDecoration = TextDecoration.none;

          if (item.isPerformer) {
            titleText = item.performerName;
            titleColor = Colors.blue.shade300;
            titleWeight = FontWeight.bold;
            textDecoration = item.isOver ? TextDecoration.lineThrough : TextDecoration.none;
          } else if (item.isReserved) {
            titleText = 'Reserved';
            titleColor = Colors.orange.shade300;
            titleWeight = FontWeight.bold;
          }

          String spotLabel = _calculateSpotLabel(item, index, spotItems);

          Widget tileContent = FadeInUp(
            child: Card(
              child: ListTile(
                leading: Text(spotLabel),
                title: Text(titleText, style: TextStyle(color: titleColor, fontWeight: titleWeight, decoration: textDecoration)),
                onTap: item.isAvailable && !item.isReserved
                    ? () => _showAddNameDialog(item.key)
                    : (item.isPerformer && !item.isOver)
                        ? () => _showSetOverDialog(item.key, item.performerName, item.isOver)
                        : null,
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                ),
              ),
            ),
          );

          if (item.isPerformer && !item.isOver) {
            return Dismissible(
              key: itemKey,
              onDismissed: (direction) {
                _handleDismissPerformer(item.key, item.performerId);
                setState(() {
                  _orderedSpotList.removeAt(index);
                });
              },
              child: tileContent,
            );
          } else {
            return Container(key: itemKey, child: tileContent);
          }
        } catch (e) {
          return Card(
            key: ValueKey('error_$index'),
            color: Colors.red.shade900,
            child: ListTile(
              title: Text("Error building item $index", style: TextStyle(color: Colors.white)),
            ),
          );
        }
      },
      onReorder: (int oldIndex, int newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = _orderedSpotList.removeAt(oldIndex);
        _orderedSpotList.insert(newIndex, item);
        _saveReorderedList(_orderedSpotList);
      },
    );
  }

  String _calculateSpotLabel(_SpotListItem item, int currentIndex, List<_SpotListItem> currentList) {
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
      return "Err";
    }
    return "?";
  }
}

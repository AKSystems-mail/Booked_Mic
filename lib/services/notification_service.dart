
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
//
import 'package:flutter/services.dart';
import 'widget_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  ValueNotifier<Map<String, int?>> get lastNotifiedPositionNotifier => _lastNotifiedPositionNotifier;
  
  // New: Notifier for the UI banner
  final ValueNotifier<String?> bannerMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isUpNextNotifier = ValueNotifier(false);

  void startListening(String userId) {
    if (_listsSubscription != null) {
      _listsSubscription!.cancel();
    }
    _listsSubscription = FirebaseFirestore.instance
        .collection('Lists')
        .where('signedUpUserIds', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      _updateAndNotifyPositions(snapshot.docs, userId);
    });
  }

  void stopListening() {
    _listsSubscription?.cancel();
    _lastNotifiedPositionNotifier.value = {};
    bannerMessageNotifier.value = null;
  }

  void dismissBanner() {
    bannerMessageNotifier.value = null;
  }

  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs, String userId) {
    final today = DateTime.now();
    final Map<String, int?> currentPositions = {};

    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listId = doc.id;
      final String listName = listData['listName'] ?? 'Unnamed List';

      final Timestamp? showTimestamp = listData['date'] as Timestamp?;
      if (showTimestamp != null) {
        final showDate = showTimestamp.toDate();
        if (showDate.year == today.year &&
            showDate.month == today.month &&
            showDate.day == today.day) {
          final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
          final numRegular = (listData['numberOfSpots'] ?? 0) as int;
          
          List<String> activeRegularPerformers = [];

          void checkSpot(String key) {
            if (spotsMap.containsKey(key)) {
              final d = spotsMap[key];
              if (d is Map && d['userId'] != null && !(d['isOver'] == true)) {
                activeRegularPerformers.add(d['userId'] as String);
              }
            }
          }

          // Strictly Regular Spots as per instructions
          for (int i = 1; i <= numRegular; i++) {
            checkSpot(i.toString());
          }

          final int currentPositionIndex = activeRegularPerformers.indexOf(userId);
          currentPositions[listId] = currentPositionIndex;

          if (currentPositionIndex != -1) {
            final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

            // Only notify if position decreased (moved forward)
            if (lastNotifiedPosition == null || currentPositionIndex < lastNotifiedPosition) {
              _showCustomPositionNotification(
                  listId,
                  listName,
                  currentPositionIndex,
                  activeRegularPerformers.length);
            }
          }
        }
      }
    }

    // Update global state
    final Map<String, int?> nextNotifierValue = Map.from(_lastNotifiedPositionNotifier.value);
    currentPositions.forEach((listId, position) {
      if (position != -1) {
        nextNotifierValue[listId] = position;
      } else {
        nextNotifierValue.remove(listId);
      }
    });
    
    List<String> currentListIdsInDocs = docs.map((d) => d.id).toList();
    _lastNotifiedPositionNotifier.value.keys
        .where((id) => !currentListIdsInDocs.contains(id))
        .toList()
        .forEach(nextNotifierValue.remove);

    if (!mapEquals(_lastNotifiedPositionNotifier.value, nextNotifierValue)) {
      _lastNotifiedPositionNotifier.value = nextNotifierValue;
    }
  }

  Future<void> _showCustomPositionNotification(
      String listId, String listName, int currentPositionIndex, int totalActivePerformers) async {
    String title = 'Spot Update: $listName';
    String body = '';
    bool isOnStage = false;
    bool isUpNext = false;

    if (currentPositionIndex == 0) {
      body = "YOU ARE ON"; // Factual status for UI/Widget
      isOnStage = true;
    } else if (currentPositionIndex == 1) {
      body = "You're up next! Get ready.";
      isUpNext = true;
    } else if (currentPositionIndex == 2) {
      body = "There is 1 performer ahead of you.";
    } else {
      body = "There are ${currentPositionIndex - 1} performers ahead of you.";
    }

    // Set UI banner
    bannerMessageNotifier.value = body;
    isUpNextNotifier.value = isUpNext || isOnStage;

    // Update Home Widget
    if (!kIsWeb) {
      WidgetService.updateUpNextWidget(
        listName: listName,
        spotNumber: (currentPositionIndex + 1).toString(),
        isOnStage: isOnStage,
        isUpNext: isUpNext,
      );
    }

    try {
      // ONLY send push notification if NOT on stage (redundant since they get notified at #2)
      if (!kIsWeb && !isOnStage) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: listId.hashCode + currentPositionIndex + DateTime.now().millisecondsSinceEpoch,
            channelKey: 'spot_updates_channel',
            title: title,
            body: body,
            payload: {'listId': listId, 'spot': (currentPositionIndex + 1).toString()},
            notificationLayout: NotificationLayout.Default,
            locked: isUpNext,
            autoDismissible: !isUpNext,
          ),
        );

        // Physical vibration on every move forward
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      // Log errors
    }
  }
}

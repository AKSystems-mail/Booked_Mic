
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
  Timer? _heartbeatTimer;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});
  
  // New: Notifier for the UI banner
  final ValueNotifier<String?> bannerMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isUpNextNotifier = ValueNotifier(false);

  // Cached widget data for heartbeat re-send
  String _lastListName = '';
  String _lastSpotNumber = '--';
  bool _lastIsOnStage = false;
  bool _lastIsUpNext = false;

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
    if (!kIsWeb) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastListName.isNotEmpty && !kIsWeb) {
        WidgetService.updateUpNextWidget(
          listName: _lastListName,
          spotNumber: _lastSpotNumber,
          isOnStage: _lastIsOnStage,
          isUpNext: _lastIsUpNext,
        );
      }
    });
  }

  void stopListening() {
    _heartbeatTimer?.cancel();
    _listsSubscription?.cancel();
    _lastNotifiedPositionNotifier.value = {};
    bannerMessageNotifier.value = null;
  }

  void dismissBanner() {
    bannerMessageNotifier.value = null;
  }

  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs, String userId) {
    final Map<String, int?> currentPositions = {};

    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listId = doc.id;
      final String listName = listData['listName'] ?? 'Unnamed List';

      final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
      final numRegular = (listData['numberOfSpots'] ?? 0) as int;
      
      int performersAhead = 0;
      bool foundMe = false;

      for (int i = 1; i <= numRegular && !foundMe; i++) {
        final key = i.toString();
        if (spotsMap.containsKey(key)) {
          final d = spotsMap[key];
          if (d is Map && d['userId'] == userId && !(d['isOver'] == true)) {
            foundMe = true;
          } else if (d is Map && !(d['isOver'] == true)) {
            performersAhead++;
          }
        }
      }

      final int? currentPositionIndex = foundMe ? performersAhead : null;
      currentPositions[listId] = currentPositionIndex;

      if (currentPositionIndex != null) {
        final int totalActive = performersAhead + 1;
        final bool isOnStage = currentPositionIndex == 0;
        final bool isUpNext = currentPositionIndex == 1;
        final String spotNumber = (currentPositionIndex + 1).toString();

        // Always update widget with latest position
        _updateWidgetData(listName, spotNumber, isOnStage, isUpNext);

        final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

        if (lastNotifiedPosition == null || currentPositionIndex < lastNotifiedPosition) {
          _showCustomPositionNotification(
              listId,
              listName,
              currentPositionIndex,
              totalActive);
        }
      }
    }

    // Update global state
    final Map<String, int?> nextNotifierValue = Map.from(_lastNotifiedPositionNotifier.value);
    currentPositions.forEach((listId, position) {
      if (position != null) {
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

  void _updateWidgetData(String listName, String spotNumber, bool isOnStage, bool isUpNext) {
    _lastListName = listName;
    _lastSpotNumber = spotNumber;
    _lastIsOnStage = isOnStage;
    _lastIsUpNext = isUpNext;
    if (!kIsWeb) {
      WidgetService.updateUpNextWidget(
        listName: listName,
        spotNumber: spotNumber,
        isOnStage: isOnStage,
        isUpNext: isUpNext,
      );
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

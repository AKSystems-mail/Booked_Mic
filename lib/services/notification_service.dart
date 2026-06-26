
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  Timer? _heartbeatTimer;
  String? _userId;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  /// Diagnostic logging to Firestore client_logs collection.
  Future<void> _logDiag(String msg, {String? uid, Map<String, dynamic>? meta}) async {
    try {
      await FirebaseFirestore.instance.collection('client_logs').add({
        'level': 'debug',
        'message': '[notif] $msg',
        'uid': uid ?? _userId ?? 'unknown',
        'meta': meta ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // New: Notifier for the UI banner
  final ValueNotifier<String?> bannerMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isUpNextNotifier = ValueNotifier(false);

  // Cached widget data for heartbeat re-send
  String _lastListName = '';
  String _lastSpotNumber = '--';
  bool _lastIsOnStage = false;
  bool _lastIsUpNext = false;

  void startListening(String userId) {
    _userId = userId;
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
    _fetchAndUpdateNearbyMicsWidget();
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
      _fetchAndUpdateNearbyMicsWidget();
    });
  }

  Future<void> _fetchAndUpdateNearbyMicsWidget() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userState = prefs.getString('last_selected_search_state') ?? 'GA';

      final snapshot = await FirebaseFirestore.instance
          .collection('Lists')
          .where('isSearchable', isEqualTo: true)
          .where('state', isEqualTo: userState)
          .get();

      final openMics = snapshot.docs.where((doc) {
        final data = doc.data();
        final spotsMap = data['spots'] as Map<String, dynamic>? ?? {};
        final filledSpotsCount =
            spotsMap.values.where((v) => v is Map && v.isNotEmpty).length;
        final regularSpots = (data['numberOfSpots'] ?? 0) as int;
        final waitlistSpots = (data['numberOfWaitlistSpots'] ?? 0) as int;
        final bucketSpots = (data['numberOfBucketSpots'] ?? 0) as int;
        return filledSpotsCount < (regularSpots + waitlistSpots + bucketSpots);
      }).length;

      WidgetService.updateNearbyMicsWidget(
        count: openMics,
        city: userState,
      );
    } catch (e) {
      debugPrint("Error updating Nearby Mics widget: $e");
    }
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
    _logDiag('update_positions_called', meta: {'numDocs': docs.length, 'userId': userId});
    final Map<String, int?> currentPositions = {};

    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listId = doc.id;
      final String listName = listData['listName'] ?? 'Unnamed List';

      final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
      final numRegular = (listData['numberOfSpots'] ?? 0) as int;
      
      int performersAhead = 0;
      bool foundMe = false;
      String? mySpotKey;

      for (int i = 1; i <= numRegular && !foundMe; i++) {
        final key = i.toString();
        if (spotsMap.containsKey(key)) {
          final d = spotsMap[key];
          if (d is Map && d['userId'] == userId) {
            mySpotKey = key;
            if (!(d['isOver'] == true)) {
              foundMe = true;
            }
          } else if (d is Map && !(d['isOver'] == true)) {
            performersAhead++;
          }
        }
      }

      _logDiag('loop_result',
        meta: {
          'listId': listId,
          'listName': listName,
          'mySpotKey': mySpotKey ?? 'null',
          'foundMe': foundMe,
          'performersAhead': performersAhead,
          'spotIsOver': mySpotKey != null && spotsMap[mySpotKey] is Map
              ? spotsMap[mySpotKey]['isOver'] is bool
                  ? spotsMap[mySpotKey]['isOver'].toString()
                  : 'not_bool'
              : 'n/a',
          'numRegular': numRegular,
          'spotsKeys': (spotsMap.keys).join(','),
        },
      );

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

        if (lastNotifiedPosition != null && currentPositionIndex < lastNotifiedPosition) {
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
    _logDiag('position_notification',
        meta: {
          'listId': listId,
          'listName': listName,
          'currentPositionIndex': currentPositionIndex,
          'totalActive': totalActivePerformers,
        });
    String title = 'Spot Update: $listName';
    String body = '';
    bool isOnStage = false;
    bool isUpNext = false;

    if (currentPositionIndex == 0) {
      body = "You're on!";
      isOnStage = true;
    } else if (currentPositionIndex == 1) {
      body = "You're up next!";
      isUpNext = true;
    } else {
      body = "Moved to spot #${currentPositionIndex + 1} • ${currentPositionIndex} ahead";
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

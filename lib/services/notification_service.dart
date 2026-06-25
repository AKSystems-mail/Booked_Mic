
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';
import '../utils/log_manager.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  Timer? _heartbeatTimer;
  Timer? _aliveCheckTimer;
  String? _userId;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});
  
  // New: Notifier for the UI banner
  final ValueNotifier<String?> bannerMessageNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isUpNextNotifier = ValueNotifier(false);

  // Track spots already notified as "set over" — listId:spotKey pairs
  final Set<String> _notifiedOverSpots = {};

  // Cached widget data for heartbeat re-send
  String _lastListName = '';
  String _lastSpotNumber = '--';
  bool _lastIsOnStage = false;
  bool _lastIsUpNext = false;

  void startListening(String userId) {
    _userId = userId;
    LogManager().init();
    LogManager().log('startListening called for userId=$userId');

    // Request notification permission BEFORE setting up Firestore listener
    // to avoid race where a snapshot fires before permission is granted
    if (!kIsWeb) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }

    if (_listsSubscription != null) {
      _listsSubscription!.cancel();
    }
    _listsSubscription = FirebaseFirestore.instance
        .collection('Lists')
        .where('signedUpUserIds', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      _updateAndNotifyPositions(snapshot.docs, userId);
    }, onError: (error) {
      debugPrint('[Notification] Firestore listener ERROR: $error');
      LogManager().log('Firestore listener ERROR: $error');
      // Write to Firestore so we can see the failure server-side
      FirebaseFirestore.instance.collection('client_logs').add({
        'level': 'error',
        'message': 'firestore_listener_error',
        'meta': {'error': error.toString(), 'userId': userId},
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    });
    _startHeartbeat();
    _startAliveCheck();
    _fetchAndUpdateNearbyMicsWidget();
  }

  Timer? _nearbyMicsTimer;

  void _startHeartbeat() {
    // Widget-only heartbeat: 10s — local broadcast, no network cost
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_lastListName.isNotEmpty && !kIsWeb) {
        WidgetService.updateUpNextWidget(
          listName: _lastListName,
          spotNumber: _lastSpotNumber,
          isOnStage: _lastIsOnStage,
          isUpNext: _lastIsUpNext,
        );
      }
    });

    // Nearby mics query: 60s — costs a Firestore read per tick
    _nearbyMicsTimer?.cancel();
    _nearbyMicsTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _fetchAndUpdateNearbyMicsWidget();
    });
  }

  void _startAliveCheck() {
    // Diagnostic heartbeat: writes to Firestore client_logs every 5 minutes
    // so we can verify the app is alive and the listener is active
    _aliveCheckTimer?.cancel();
    _aliveCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_userId != null) {
        FirebaseFirestore.instance.collection('client_logs').add({
          'level': 'info',
          'message': 'app_heartbeat',
          'meta': {'userId': _userId, 'type': 'periodic_alive_check'},
          'timestamp': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
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
    _nearbyMicsTimer?.cancel();
    _aliveCheckTimer?.cancel();
    _listsSubscription?.cancel();
    _lastNotifiedPositionNotifier.value = {};
    _notifiedOverSpots.clear();
    bannerMessageNotifier.value = null;
  }

  void dismissBanner() {
    bannerMessageNotifier.value = null;
  }

  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs, String userId) {
    final Map<String, int?> currentPositions = {};
    bool foundUserInAnyList = false;

    LogManager().log('_updateAndNotifyPositions: ${docs.length} docs received for userId=$userId');

    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listId = doc.id;
      final String listName = listData['listName'] ?? 'Unnamed List';
      LogManager().log('  Doc: id=$listId name=$listName');

      final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
      final numRegular = (listData['numberOfSpots'] ?? 0) as int;
      
      int performersAhead = 0;
      bool foundMe = false;

      for (int i = 1; i <= numRegular && !foundMe; i++) {
        final key = i.toString();
        if (spotsMap.containsKey(key)) {
          final d = spotsMap[key];
          if (d is Map && d['userId'] == userId) {
            if (d['isOver'] == true) {
              // User's spot was marked as set-over — fire notification
              final overSpotKey = '$listId:$key';
              if (!_notifiedOverSpots.contains(overSpotKey)) {
                _notifiedOverSpots.add(overSpotKey);
                _showSetOverNotification(listName);
              }
            } else {
              foundMe = true;
            }
          } else if (d is Map && !(d['isOver'] == true)) {
            performersAhead++;
          }
        }
      }

      final int? currentPositionIndex = foundMe ? performersAhead : null;
      currentPositions[listId] = currentPositionIndex;
      LogManager().log('  Position: foundMe=$foundMe performersAhead=$performersAhead currentPositionIndex=$currentPositionIndex');

      if (currentPositionIndex != null) {
        foundUserInAnyList = true;
        final int totalActive = performersAhead + 1;
        final bool isOnStage = currentPositionIndex == 0;
        final bool isUpNext = currentPositionIndex == 1;
        final String spotNumber = (currentPositionIndex + 1).toString();

        // Always update widget with latest position
        _updateWidgetData(listName, spotNumber, isOnStage, isUpNext);

        final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

        final bool shouldFire = lastNotifiedPosition == null || currentPositionIndex < lastNotifiedPosition;
        LogManager().log('  Notification decision: lastNotified=$lastNotifiedPosition shouldFire=$shouldFire');

        debugPrint('[Notification] Decision: listId=$listId pos=$currentPositionIndex lastNotified=$lastNotifiedPosition shouldFire=$shouldFire');

        if (lastNotifiedPosition == null || currentPositionIndex < lastNotifiedPosition) {
          _showCustomPositionNotification(
              listId,
              listName,
              currentPositionIndex,
              totalActive);
        }
      }
    }

    // If user is no longer found in ANY list (e.g. list was deleted or signup removed),
    // clear the widget data so it stops showing stale info
    LogManager().log('  Post-loop: foundUserInAnyList=$foundUserInAnyList _lastListName="$_lastListName"');
    if (!foundUserInAnyList && _lastListName.isNotEmpty) {
      LogManager().log('  Clearing widget data — user no longer in any list');
      _updateWidgetData('', '--', false, false);
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
      body = "There are 2 performers ahead of you.";
    } else {
      body = "There are $currentPositionIndex performers ahead of you.";
    }

    // Set UI banner
    bannerMessageNotifier.value = body;
    isUpNextNotifier.value = isUpNext || isOnStage;

    debugPrint('[Notification] _showCustomPositionNotification called: list=$listName pos=$currentPositionIndex isOnStage=$isOnStage');
    LogManager().log('_showCustomPositionNotification: list=$listName pos=$currentPositionIndex isOnStage=$isOnStage kIsWeb=$kIsWeb');

    try {
      // ONLY send push notification if NOT on stage (redundant since they get notified at #2)
      if (!kIsWeb && !isOnStage) {
        debugPrint('[Notification] Attempting AwesomeNotifications().createNotification...');
        LogManager().log('Calling AwesomeNotifications().createNotification()...');
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
        debugPrint('[Notification] createNotification succeeded');
        LogManager().log('createNotification SUCCEEDED');
        // Firestore diagnostic: confirm notification was created
        FirebaseFirestore.instance.collection('client_logs').add({
          'level': 'info',
          'message': 'notification_created',
          'meta': {'listId': listId, 'listName': listName, 'position': currentPositionIndex, 'body': body},
          'timestamp': FieldValue.serverTimestamp(),
        }).catchError((_) {});

        // Physical vibration on every move forward
        HapticFeedback.heavyImpact();
      } else if (kIsWeb) {
        debugPrint('[Notification] Skipped: web platform');
        LogManager().log('Skipped notification: kIsWeb=true');
      } else if (isOnStage) {
        debugPrint('[Notification] Skipped: user is on stage');
        LogManager().log('Skipped notification: isOnStage=true');
      }
    } catch (e) {
      debugPrint('[Notification] ERROR creating notification: $e');
      LogManager().log('ERROR creating notification: $e');
      // Firestore diagnostic log
      try {
        await FirebaseFirestore.instance.collection('client_logs').add({
          'level': 'error',
          'message': 'notification_create_failed',
          'meta': {'error': e.toString(), 'listId': listId, 'listName': listName, 'position': currentPositionIndex},
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _showSetOverNotification(String listName) async {
    debugPrint('[Notification] _showSetOverNotification called: list=$listName');
    LogManager().log('_showSetOverNotification: list=$listName');

    if (kIsWeb) {
      debugPrint('[Notification] Skipped set-over: web platform');
      return;
    }

    // Show a notification that requires manual dismiss
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 'set_over_${listName}'.hashCode + DateTime.now().millisecondsSinceEpoch,
          channelKey: 'spot_updates_channel',
          title: 'Set Over: $listName',
          body: 'Your set is over! Great job!',
          payload: {'listName': listName, 'type': 'set_over'},
          notificationLayout: NotificationLayout.Default,
          locked: false,
          autoDismissible: true,
        ),
      );
      debugPrint('[Notification] Set-over notification SUCCEEDED');
      LogManager().log('Set-over notification SUCCEEDED');

      // Firestore diagnostic
      FirebaseFirestore.instance.collection('client_logs').add({
        'level': 'info',
        'message': 'set_over_notification_created',
        'meta': {'listName': listName},
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[Notification] ERROR creating set-over notification: $e');
      LogManager().log('ERROR creating set-over notification: $e');
      FirebaseFirestore.instance.collection('client_logs').add({
        'level': 'error',
        'message': 'set_over_notification_failed',
        'meta': {'error': e.toString(), 'listName': listName},
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
  }
}

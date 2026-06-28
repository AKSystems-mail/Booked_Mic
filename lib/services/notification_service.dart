
import 'dart:async';
import 'dart:convert';
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

  static const String _prefsKey = 'last_notified_positions';

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  Timer? _heartbeatTimer;
  String? _userId;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

  ValueNotifier<Map<String, int?>> get lastNotifiedPositionNotifier => _lastNotifiedPositionNotifier;

  /// Tracks which lists have been initialized from the first snapshot.
  /// Prevents stale SharedPreferences values (e.g. position 0 from a prior
  /// session) from suppressing all subsequent advancement notifications.
  final Set<String> _initializedListIds = {};

  Future<void> _logDiag(String msg,
      {String? uid, Map<String, dynamic>? meta, String? listId}) async {
    final effectiveUid = uid ?? _userId ?? 'unknown';
    try {
      await FirebaseFirestore.instance.collection('client_logs').add({
        'level': 'debug',
        'message': '[notif] $msg',
        'uid': effectiveUid,
        'meta': meta ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    final diagKey = listId ?? 'general';
    try {
      final docRef = FirebaseFirestore.instance
          .doc('diagnostics/$effectiveUid/snapshots/$diagKey');
      await docRef.set({
        'message': '[notif] $msg',
        'meta': meta ?? {},
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    debugPrint('[notif] $msg${meta != null ? ' — $meta' : ''}');
  }

  Future<void> _loadLastNotifiedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = Map<String, dynamic>.from(
            const JsonDecoder().convert(raw) as Map);
        _lastNotifiedPositionNotifier.value = decoded.map(
            (k, v) => MapEntry(k, v as int?));
      }
    } catch (_) {}
  }

  Future<void> _saveLastNotifiedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          const JsonEncoder().convert(_lastNotifiedPositionNotifier.value));
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

  Future<void> startListening(String userId) async {
    _userId = userId;
    if (_listsSubscription != null) {
      _listsSubscription!.cancel();
    }
    // ── Load persisted positions FIRST so the first snapshot callback ──
    // has the correct lastNotifiedPosition.  Must be done before
    // subscribing to avoid a race where the listener saves a position
    // that gets overwritten by a stale SharedPreferences value.
    await _loadLastNotifiedPosition();

    void _onData(QuerySnapshot snapshot) {
      _updateAndNotifyPositions(snapshot.docs, userId);
    }

    void _onError(Object error) {
      debugPrint('[notif] Snapshot listener error: $error — reconnecting in 5s');
      Future.delayed(const Duration(seconds: 5), () {
        startListening(userId);
      });
    }

    void _onDone() {
      debugPrint('[notif] Snapshot listener closed — reconnecting in 5s');
      Future.delayed(const Duration(seconds: 5), () {
        startListening(userId);
      });
    }

    _listsSubscription = FirebaseFirestore.instance
        .collection('Lists')
        .where('signedUpUserIds', arrayContains: userId)
        .snapshots()
        .listen(_onData, onError: _onError, onDone: _onDone);
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
    _initializedListIds.clear();
    bannerMessageNotifier.value = null;
  }

  void dismissBanner() {
    bannerMessageNotifier.value = null;
  }

  // ── Terminology ────────────────────────────────────────────────
  // This method runs on every snapshot fire. For each list the user
  // is signed up for, it:
  //   1. Walks Spot Keys 1..numRegular, counting non‑isOver performers
  //      as the Ahead Count.
  //   2. Finds my spot — skipping it if Marked Over (isOver=true).
  //   3. Computes Current Position (0‑based; 0 = On Stage).
  //   4. Detects an Advance: Current Position < last notified position.
  //   5. Fires a Position Notification on Advance.
  // ────────────────────────────────────────────────────────────────
  void _updateAndNotifyPositions(List<QueryDocumentSnapshot> docs, String userId) {
    _logDiag('update_positions_called',
        meta: {'numDocs': docs.length, 'userId': userId});
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
          } else if (d is Map && d['name'] != null && d['name'].toString().isNotEmpty && !(d['isOver'] == true)) {
            performersAhead++;
          }
        }
      }

      _logDiag('loop_result',
        listId: listId,
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

        // ── First snapshot for this list: set baseline from current state ─
        // This prevents stale SharedPreferences values (e.g. position 0 from
        // a prior session) from poisoning the advancement detection.
        if (!_initializedListIds.contains(listId)) {
          _initializedListIds.add(listId);
          _lastNotifiedPositionNotifier.value[listId] = currentPositionIndex;
          _saveLastNotifiedPosition();
          continue;
        }

        final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

        if (lastNotifiedPosition != null && currentPositionIndex < lastNotifiedPosition) {
          // ── Missed-advancement guard ────────────────────────────────
          // When the app is backgrounded, Android may suspend the
          // snapshot listener.  On reconnection we get the final state
          // but missed all intermediate advancements.
          // If we jumped to position 0 (stage) from more than 1 ahead,
          // fire the critical "You're up next!" as the last non-silent
          // notification instead of silently dropping it.
          // ────────────────────────────────────────────────────────────
          if (currentPositionIndex == 0 && lastNotifiedPosition > 1) {
            _showCustomPositionNotification(
                listId, listName, 1, lastNotifiedPosition);
          } else if (currentPositionIndex > 0) {
            _showCustomPositionNotification(
                listId, listName, currentPositionIndex, totalActive);
          }
          // position 0 with lastNotifiedPosition == 1: silent advancement
          // to stage — no push needed.
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
      _saveLastNotifiedPosition(); // persist through restarts
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

  // ── Terminology ────────────────────────────────────────────────
  // Position Notification — fires on Advance.
  //   currentPositionIndex==0 → On Stage (banner+widget only, no push)
  //   currentPositionIndex==1 → Up Next (locked notif, heavy haptic)
  //   currentPositionIndex>1  → Spot #N • M ahead (standard push)
  // ────────────────────────────────────────────────────────────────
  Future<void> _showCustomPositionNotification(
      String listId, String listName, int currentPositionIndex, int totalActivePerformers) async {
    _logDiag('position_notification',
        listId: listId,
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
      isOnStage = true;
      isUpNextNotifier.value = true;
      // No banner or notification — silent stage
      return;
    } else if (currentPositionIndex == 1) {
      body = "You're up next!";
      isUpNext = true;
    } else {
      body = "${currentPositionIndex} ahead of you.";
    }

    // Set UI banner
    bannerMessageNotifier.value = body;
    isUpNextNotifier.value = isUpNext || isOnStage;

    try {
      // Local notification for spot #2 only ("You're up next!").
      // Spot #1 (on stage) gets no notification — performer is already live.
      // All other positions handled by FCM system push.
      if (!kIsWeb && currentPositionIndex == 1) {
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

        // Physical vibration on move forward
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      // Log errors
    }
  }
}

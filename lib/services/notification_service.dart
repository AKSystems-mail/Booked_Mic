
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  Timer? _heartbeatTimer;
  String? _userId;

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

    void _onData(QuerySnapshot snapshot) {
      _updatePositions(snapshot.docs, userId);
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
  }

  void _updatePositions(List<QueryDocumentSnapshot> docs, String userId) {
    for (var doc in docs) {
      final listData = doc.data() as Map<String, dynamic>? ?? {};
      final String listName = listData['listName'] ?? 'Unnamed List';

      final spotsMap = listData['spots'] as Map<String, dynamic>? ?? {};
      final numRegular = (listData['numberOfSpots'] ?? 0) as int;

      int performersAhead = 0;
      bool foundMe = false;

      for (int i = 1; i <= numRegular && !foundMe; i++) {
        final key = i.toString();
        if (spotsMap.containsKey(key)) {
          final d = spotsMap[key];
          if (d is Map && d['userId'] == userId) {
            if (!(d['isOver'] == true)) {
              foundMe = true;
            }
          } else if (d is Map && d['name'] != null && d['name'].toString().isNotEmpty && !(d['isOver'] == true)) {
            performersAhead++;
          }
        }
      }

      if (foundMe) {
        final int totalActive = performersAhead + 1;
        final bool isOnStage = performersAhead == 0;
        final bool isUpNext = performersAhead == 1;
        final String spotNumber = (performersAhead + 1).toString();

        _updateWidgetData(listName, spotNumber, isOnStage, isUpNext);
      }
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
}

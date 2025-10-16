
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StreamSubscription<QuerySnapshot>? _listsSubscription;
  final ValueNotifier<Map<String, int?>> _lastNotifiedPositionNotifier =
      ValueNotifier({});

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
          final numWaitlist = (listData['numberOfWaitlistSpots'] ?? 0) as int;
          
          List<String> activePerformers = [];

          checkSpot(String key) {
            if (spotsMap.containsKey(key)) {
              final d = spotsMap[key];
              if (d is Map && d['userId'] != null && !(d['isOver'] == true)) {
                activePerformers.add(d['userId'] as String);
              }
            }
          }

          for (int i = 1; i <= numRegular; i++) {
            checkSpot(i.toString());
          }
          for (int i = 1; i <= numWaitlist; i++) {
            checkSpot("W\$i");
          }

          final int currentPositionIndex = activePerformers.indexOf(userId);

          currentPositions[listId] = currentPositionIndex;

          if (currentPositionIndex != -1) {
            final int? lastNotifiedPosition = _lastNotifiedPositionNotifier.value[listId];

            if (lastNotifiedPosition == null || lastNotifiedPosition != currentPositionIndex) {
              _showCustomPositionNotification(
                  listId,
                  listName,
                  currentPositionIndex,
                  activePerformers.length);
            }
          }
        }
      }
    }

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

    if (_lastNotifiedPositionNotifier.value != nextNotifierValue) {
      _lastNotifiedPositionNotifier.value = nextNotifierValue;
    }
  }

  Future<void> _showCustomPositionNotification(
      String listId, String listName, int currentPositionIndex, int totalActivePerformers) async {
    String title = 'Spot Update: \$listName';
    String body = '';
    bool playHapticFeedback = false;

    if (currentPositionIndex == 0) {
      body = "You're up next!";
      playHapticFeedback = true;
    } else if (currentPositionIndex == 1) {
      body = "There is 1 performer ahead of you.";
    } else if (currentPositionIndex > 1) {
      body = "There are \$currentPositionIndex performers ahead of you.";
    } else {
      return;
    }

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: listId.hashCode + currentPositionIndex + DateTime.now().millisecondsSinceEpoch,
          channelKey: 'spot_updates_channel',
          title: title,
          body: body,
          payload: {'listId': listId, 'spot': (currentPositionIndex + 1).toString()},
          notificationLayout: NotificationLayout.Default,
          locked: playHapticFeedback,
          autoDismissible: !playHapticFeedback,
        ),
      );

      if (playHapticFeedback) {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      // Log errors to a service
    }
  }
}

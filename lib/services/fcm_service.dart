
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  StreamSubscription<String?>? _tokenSubscription;

  Future<void> init(String userId) async {
    if (kIsWeb) {
      debugPrint('[FCM] Skipping registration on web.');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied.');
      return;
    }

    // On iOS, explicitly trigger APNs registration.  If permission was already
    // granted in a previous launch, requestPermission() does NOT call
    // registerForRemoteNotifications() again — this call forces it.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await messaging.getAPNSToken();
    }

    // Retry getToken() — on iOS, the APNs token may not be available
    // immediately after registration, and getToken() throws if it's null.
    String? token;
    for (int i = 0; i < 10; i++) {
      try {
        token = await messaging.getToken();
        if (token != null) break;
      } catch (e) {
        debugPrint('[FCM] getToken attempt $i failed: $e');
      }
      if (i < 9) await Future.delayed(const Duration(seconds: 2));
    }

    if (token != null) {
      await _storeToken(userId, token);
    } else {
      debugPrint('[FCM] Could not obtain FCM token after 10 attempts');
    }

    _tokenSubscription = messaging.onTokenRefresh.listen((newToken) {
      _storeToken(userId, newToken);
    });
  }

  Future<void> _storeToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmTokens': [token]}, SetOptions(merge: true));
      debugPrint('[FCM] Token stored for user $userId');
    } catch (e) {
      debugPrint('[FCM] Error storing token: $e');
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}

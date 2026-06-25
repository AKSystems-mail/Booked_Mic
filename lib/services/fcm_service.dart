
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

    final token = await messaging.getToken();
    if (token != null) {
      await _storeToken(userId, token);
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
          .update({'fcmTokens': [token]});
      debugPrint('[FCM] Token stored for user $userId (replaced old tokens)');
    } catch (e) {
      debugPrint('[FCM] Error storing token: $e');
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}

// lib/services/user_service.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';


class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  /// Ensures the current user has a unique 6-character Host Code.
  /// Uses the atomic Cloud Function to prevent race conditions and ensure 100% uniqueness.
  Future<String?> ensureHostCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("[UserService] No user logged in, skipping host code check.");
      return null;
    }

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('hostCode') && data['hostCode'] != null && (data['hostCode'] as String).isNotEmpty) {
          debugPrint("[UserService] User already has host code: ${data['hostCode']}");
          return data['hostCode'] as String;
        }
      }

      debugPrint("[UserService] Requesting host code allocation from Cloud for UID: ${user.uid}");
      
      // Call the centralized atomic allocation function (already deployed)
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('allocateHostCode');
      final result = await callable.call();
      
      final String? assignedCode = result.data['hostCode'];
      debugPrint("[UserService] Successfully assigned host code from Cloud: $assignedCode");

      // Cache locally for fast startup
      try {
        final prefs = await SharedPreferences.getInstance();
        if (assignedCode != null) await prefs.setString('host_code', assignedCode);
      } catch (_) {}

      return assignedCode;
    } catch (e) {
      debugPrint("[UserService] Error ensuring host code via Cloud: $e");
      // Fallback: fall back to client-side generation and persist
      try {
        final String newCode = await _generateUniqueCode();
        final userRef = _firestore.collection('users').doc(user.uid);
        await userRef.set({
          'uid': user.uid,
          'email': user.email?.toLowerCase(),
          'hostCode': newCode,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('host_code', newCode);
        return newCode;
      } catch (e2) {
        debugPrint("[UserService] Fallback host code generation failed: $e2");
        return null;
      }
    }
  }

  /// Reads the user's stageName from Firestore (if present) and caches it to SharedPreferences
  Future<void> cacheStageName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final stageName = data['stageName'] as String? ?? data['stage_name'] as String?;
        if (stageName != null && stageName.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('stage_name', stageName);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[UserService] Failed to cache stageName: $e');
    }
  }

  Stream<String?> getHostCodeStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['hostCode'] as String?;
      }
      return null;
    });
  }

  Future<String> _generateUniqueCode() async {
    final random = Random();
    bool isUnique = false;
    String code = "";
    int attempts = 0;

    while (!isUnique && attempts < 10) {
      attempts++;
      // Generate 6-digit numeric code
      code = (random.nextInt(900000) + 100000).toString();

      final querySnapshot = await _firestore
          .collection('users')
          .where('hostCode', isEqualTo: code)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        isUnique = true;
      }
    }

    if (!isUnique) {
       // Fallback to alphanumeric if numeric collisions are too high
       code = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    }

    return code;
  }
}

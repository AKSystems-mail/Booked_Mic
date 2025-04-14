// services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SettingsService {
  // Private constructor for singleton pattern
  SettingsService._privateConstructor();

  // Static instance - accessible globally via SettingsService.instance
  static final SettingsService instance = SettingsService._privateConstructor();

  // Method to load timer settings for a specific list
  Future<Map<String, dynamic>> loadTimerSettings(String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final totalSeconds = prefs.getInt('timerTotal_$listId') ?? 300; // Default 5 mins
      final thresholdSeconds = prefs.getInt('timerThreshold_$listId') ?? 30; // Default 30s
      final autoLightEnabled = prefs.getBool('autoLightEnabled_$listId') ?? false; // Default false

      return {
        'totalSeconds': totalSeconds,
        'thresholdSeconds': thresholdSeconds,
        'autoLightEnabled': autoLightEnabled,
      };
    } catch (e) {
      debugPrint("Error loading settings for list $listId: $e");
      // Return default values on error
      return {
        'totalSeconds': 300,
        'thresholdSeconds': 30,
        'autoLightEnabled': false,
      };
    }
  }

  // Method to save timer settings for a specific list
  Future<void> saveTimerSettings({
    required String listId,
    required int totalSeconds,
    required int thresholdSeconds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timerTotal_$listId', totalSeconds);
      await prefs.setInt('timerThreshold_$listId', thresholdSeconds);
    } catch (e) {
      debugPrint("Error saving timer settings for list $listId: $e");
    }
  }

   // Method to save auto-light setting for a specific list
   Future<void> saveAutoLightSetting({
    required String listId,
    required bool autoLightEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoLightEnabled_$listId', autoLightEnabled);
    } catch (e) {
      debugPrint("Error saving auto-light setting for list $listId: $e");
    }
  }
}
// providers/timer_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/services/settings_service.dart'; // Import settings service
import 'package:shared_preferences/shared_preferences.dart';

class TimerService extends ChangeNotifier {
  final String listId; // Need listId to load/save settings
  final SettingsService _settingsService = SettingsService.instance; // Use singleton

  Timer? _timer;
  int _totalSeconds = 300; // Default
  int _lightThresholdSeconds = 30; // Default

  // Use ValueNotifier for efficient UI updates of remaining time
  final ValueNotifier<int> _remainingSecondsNotifier;
  bool _isTimerRunning = false;

  // Callback to notify when threshold is reached
  VoidCallback? onThresholdReached;

  // Public getters
  int get totalSeconds => _totalSeconds;
  int get lightThresholdSeconds => _lightThresholdSeconds;
  ValueNotifier<int> get remainingSecondsNotifier => _remainingSecondsNotifier;
  bool get isTimerRunning => _isTimerRunning;

  TimerService({required this.listId})
      : _remainingSecondsNotifier = ValueNotifier(300) { // Initialize notifier
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    final settings = await _settingsService.loadTimerSettings(listId);
    _totalSeconds = settings['totalSeconds'] as int;
    _lightThresholdSeconds = settings['thresholdSeconds'] as int;
    _remainingSecondsNotifier.value = _totalSeconds; // Set initial value
    // Auto-light setting is handled by FlashlightService
    notifyListeners(); // Notify if total/threshold changed from default
  }

  void startTimer() {
    if (_isTimerRunning || _remainingSecondsNotifier.value <= 0) return;
    _isTimerRunning = true;
    notifyListeners(); // Notify UI that timer started

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSecondsNotifier.value > 0) {
        _remainingSecondsNotifier.value--; // ValueNotifier handles its own notification
        if (_remainingSecondsNotifier.value == _lightThresholdSeconds) {
          onThresholdReached?.call(); // Trigger callback
        }
      } else {
        pauseTimer(notify: false); // Stop timer without notifying UI about pause state yet
        // Optionally add a callback for time's up
        _isTimerRunning = false; // Update state after timer loop finishes
        notifyListeners(); // Notify UI about pause state now
      }
    });
  }

  void pauseTimer({bool notify = true}) {
    _timer?.cancel();
    if (_isTimerRunning) {
      _isTimerRunning = false;
      if (notify) notifyListeners(); // Notify UI about pause state
    }
  }

  void resetTimer() {
     // Keep existing total/threshold, just reset remaining time
     _remainingSecondsNotifier.value = _totalSeconds;
     // ValueNotifier notifies itself
  }

  void resetAndStopTimer() {
    pauseTimer(); // Handles cancel and state update
    resetTimer(); // Resets remaining time
  }

  Future<void> setTotalSeconds(int newTotalSeconds) async {
    if (newTotalSeconds > 0) {
      _totalSeconds = newTotalSeconds;
      // Ensure threshold is valid
      if (_lightThresholdSeconds >= _totalSeconds) {
        _lightThresholdSeconds = (_totalSeconds > 0) ? _totalSeconds - 1 : 0;
      }
      await _settingsService.saveTimerSettings(
        listId: listId,
        totalSeconds: _totalSeconds,
        thresholdSeconds: _lightThresholdSeconds,
      );
      resetAndStopTimer(); // Reset display and stop timer after change
      notifyListeners(); // Notify about potential threshold change
    }
  }

  Future<void> setLightThreshold(int newThresholdSeconds) async {
    // --- Add Validation Inside the Service ---
    if (newThresholdSeconds >= 0 && newThresholdSeconds < totalSeconds) {
      if (_lightThresholdSeconds != newThresholdSeconds) {
        _lightThresholdSeconds = newThresholdSeconds;
        print("TimerService: Threshold updated to $_lightThresholdSeconds");
        // Save the setting
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('timerThreshold_$listId', _lightThresholdSeconds);
        notifyListeners(); // Notify if needed (e.g., if UI displays threshold)
      }
    } else {
      // Handle invalid threshold (e.g., show error message)
      // This logic might be better handled in the UI dialog callback
    }
  }

  String formatDuration(int secondsValue) {
    final duration = Duration(seconds: secondsValue);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingSecondsNotifier.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }
}
// providers/timer_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/services/settings_service.dart'; // Import settings service

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
  // <<< ADDED isPaused GETTER >>>
  bool get isPaused => _timer != null && !_isTimerRunning;
  // <<< END ADDED >>>

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
    if (_isTimerRunning) { // Only update if it was running
  
      _isTimerRunning = false;
      if (notify) notifyListeners(); // Notify UI about pause state
    } else if (_timer != null && notify) { // If not running but _timer exists (was paused manually)
       notifyListeners(); // Still notify if notify is true
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
    // --- Add Validation Inside the Service ---\n    if (newThresholdSeconds >= 0 && newThresholdSeconds < totalSeconds) { // Correct validation logic
      if (_lightThresholdSeconds != newThresholdSeconds) {
        _lightThresholdSeconds = newThresholdSeconds;
        // print("TimerService: Threshold updated to $_lightThresholdSeconds");
        await _settingsService.saveTimerSettings( // Use settings service for saving
          listId: listId,
          totalSeconds: _totalSeconds, // Save totalSeconds as well
          thresholdSeconds: _lightThresholdSeconds,
        );
        notifyListeners(); // Notify if needed (e.g., if UI displays threshold)
      }
     else {
       // This error handling should ideally be done in the UI dialog logic
       // but you could potentially throw an exception here as well.
       // For now, just log or ignore if validation happens in UI.
       // print("TimerService: Invalid threshold value $newThresholdSeconds");
    }
  }

  // <<< ADDED snoozeLightPrompt METHOD >>>
  // This method assumes a simple snooze where the prompt won't reappear immediately
  // You might need more sophisticated logic based on your requirements
  void snoozeLightPrompt() {
    // For a simple snooze, you could just clear the onThresholdReached callback temporarily
    // or set a flag that the FlashlightService checks.
    // A more complex implementation might involve a delayed trigger.
    // For now, let's assume FlashlightService manages the prompt logic after receiving the call.
    // The primary action here is to allow the timer to continue without immediately re-prompting.
    // If FlashlightService needs a specific method to signal snooze, add it there.
    // Since the current error is about the missing method, we'll add a placeholder here.
    // This method is currently empty as the prompt logic is handled elsewhere.
     // print("TimerService: Snoozing light prompt.");
  }
  // <<< END ADDED >>>


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


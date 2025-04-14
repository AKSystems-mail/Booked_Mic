// providers/flashlight_service.dart
import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:myapp/services/settings_service.dart'; // Import settings service
import 'package:myapp/providers/timer_service.dart'; // Import timer service

class FlashlightService extends ChangeNotifier {
  final String listId;
  final TimerService timerService; // Depend on TimerService
  final SettingsService _settingsService = SettingsService.instance;

  bool _isFlashlightOn = false;
  bool _autoLightEnabled = false;
  bool _isTorchAvailable = false;

  // Callback for showing prompt in UI
  Future<bool?> Function()? showLightPromptCallback;
  // Callback for showing errors in UI
  void Function(String message)? showErrorCallback;

  bool get isFlashlightOn => _isFlashlightOn;
  bool get autoLightEnabled => _autoLightEnabled;

  FlashlightService({required this.listId, required this.timerService}) {
    _loadInitialSettings();
    _checkTorchAvailability();
    // Listen to the timer service for threshold reached
    timerService.onThresholdReached = _handleThresholdReached;
  }

   Future<void> _loadInitialSettings() async {
    final settings = await _settingsService.loadTimerSettings(listId);
    _autoLightEnabled = settings['autoLightEnabled'] as bool;
    notifyListeners(); // Notify UI about initial auto-light state
  }

   Future<void> _checkTorchAvailability() async {
      try {
        _isTorchAvailable = await TorchLight.isTorchAvailable();
      } catch (e) {
         _isTorchAvailable = false;
         debugPrint("Error checking torch availability: $e");
      }
   }

  Future<void> setAutoLightEnabled(bool enabled) async {
    _autoLightEnabled = enabled;
    await _settingsService.saveAutoLightSetting(
        listId: listId, autoLightEnabled: enabled);
    notifyListeners();
    // Optionally turn off light if auto-light is disabled and light is on?
    // if (!enabled && _isFlashlightOn) {
    //   turnFlashlightOff();
    // }
  }

  // Called by TimerService when threshold is reached
  void _handleThresholdReached() {
    if (_autoLightEnabled) {
      if (!_isFlashlightOn) {
        debugPrint("Auto-light enabled, turning flashlight ON.");
        turnFlashlightOn();
      } else {
        debugPrint("Auto-light enabled, but flashlight already ON.");
      }
    } else {
      debugPrint("Auto-light disabled, requesting prompt.");
      _requestLightPrompt();
    }
  }

  // Request UI to show the prompt
  Future<void> _requestLightPrompt() async {
     if (showLightPromptCallback != null) {
       final bool? confirm = await showLightPromptCallback!();
       if (confirm == true) {
         debugPrint("Host chose 'Yes' to light prompt.");
         if (!_isFlashlightOn) {
           turnFlashlightOn();
         } else {
           debugPrint("Flashlight already ON when prompt confirmed.");
         }
       } else {
         debugPrint("Host chose 'No' to light prompt.");
       }
     } else {
        debugPrint("showLightPromptCallback not set in UI");
     }
  }

  Future<void> turnFlashlightOn() async {
    if (!_isTorchAvailable) {
      _handleTorchError("Flashlight not available.");
      return;
    }
    if (_isFlashlightOn) return; // Already on

    try {
      await TorchLight.enableTorch();
      _isFlashlightOn = true;
      notifyListeners();
      debugPrint("Flashlight turned ON.");
    } on Exception catch (e) {
      _handleTorchError("Error enabling torch: $e");
    }
  }

  Future<void> turnFlashlightOff() async {
    if (!_isTorchAvailable || !_isFlashlightOn) return; // Not available or already off

    try {
      await TorchLight.disableTorch();
      _isFlashlightOn = false;
      notifyListeners();
      debugPrint("Flashlight turned OFF.");
    } on Exception catch (e) {
      _handleTorchError("Error disabling torch: $e");
    }
  }

  Future<void> toggleFlashlight() async {
    if (_isFlashlightOn) {
      await turnFlashlightOff();
    } else {
      await turnFlashlightOn();
    }
  }

  void _handleTorchError(dynamic message) {
    debugPrint("Flashlight Error: $message");
    showErrorCallback?.call('Flashlight Error: $message');
  }

   // Ensure flashlight is off when service is disposed
   @override
   void dispose() {
     // Clean up listener to avoid memory leaks
     timerService.onThresholdReached = null;
     // Attempt to turn off flashlight
     if (_isFlashlightOn) {
        turnFlashlightOff();
     }
     super.dispose();
   }
}
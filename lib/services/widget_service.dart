// lib/services/widget_service.dart

import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static const String _groupId = 'group.bookedmic.app'; // For iOS App Groups
  static const String _androidWidgetName = 'BookedMicWidgetProvider';

  /// Updates the 'Up Next' widget with the user's current position and list name.
  static Future<void> updateUpNextWidget({
    required String listName,
    required String spotNumber,
    required bool isOnStage,
    required bool isUpNext,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('list_name', listName);
      await HomeWidget.saveWidgetData<String>('spot_number', spotNumber);
      await HomeWidget.saveWidgetData<bool>('is_on_stage', isOnStage);
      await HomeWidget.saveWidgetData<bool>('is_up_next', isUpNext);
      
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: 'UpNextWidget',
      );
    } catch (e) {
      debugPrint("Error updating Up Next widget: $e");
    }
  }

  /// Updates the 'Nearby Mics' widget with the count of active lists.
  static Future<void> updateNearbyMicsWidget({
    required int count,
    required String city,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('nearby_count', count);
      await HomeWidget.saveWidgetData<String>('nearby_city', city);
      
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        iOSName: 'NearbyMicsWidget',
      );
    } catch (e) {
      debugPrint("Error updating Nearby Mics widget: $e");
    }
  }
}

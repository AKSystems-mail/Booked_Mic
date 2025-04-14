// widgets/timer_control_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';

class TimerControlBar extends StatelessWidget implements PreferredSizeWidget {
  final Color backgroundColor;
  final VoidCallback onSetTotalDialog; // Callback to show dialog in parent
  final VoidCallback onSetThresholdDialog; // Callback to show dialog in parent

  const TimerControlBar({
    super.key,
    required this.backgroundColor,
    required this.onSetTotalDialog,
    required this.onSetThresholdDialog,
  });

  @override
  Widget build(BuildContext context) {
    // Use watch only where necessary to trigger rebuilds
    final timerService = context.watch<TimerService>();
    final flashlightService = context.watch<FlashlightService>();
    final Color timerColor = Colors.white; // Example color

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Play/Pause Button
          IconButton(
            icon: Icon(
              timerService.isTimerRunning
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 30,
            ),
            color: timerColor,
            tooltip: timerService.isTimerRunning ? 'Pause Timer' : 'Start Timer',
            // Use read for actions that don't need to listen to state changes directly
            onPressed: timerService.isTimerRunning
                ? () => context.read<TimerService>().pauseTimer()
                : () => context.read<TimerService>().startTimer(),
          ),

          // Timer Display (using ValueListenableBuilder for efficiency)
          ValueListenableBuilder<int>(
            valueListenable: timerService.remainingSecondsNotifier,
            builder: (context, remainingSeconds, child) => Text(
              timerService.formatDuration(remainingSeconds),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: timerColor,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Reset Button
          IconButton(
            icon: Icon(Icons.replay, size: 28),
            color: timerColor,
            tooltip: 'Reset Timer',
            onPressed: () => context.read<TimerService>().resetAndStopTimer(),
          ),

          // Set Total Duration Button
          IconButton(
            icon: Icon(Icons.timer_outlined, size: 28),
            color: timerColor,
            tooltip: 'Set Total Duration',
            onPressed: onSetTotalDialog, // Trigger dialog in parent
          ),

          // Set Threshold Button
          IconButton(
            icon: Icon(Icons.alarm_add_outlined, size: 28),
            color: timerColor,
            // Tooltip shows current threshold from service
            tooltip: 'Set Light Threshold (${timerService.lightThresholdSeconds}s)',
            onPressed: onSetThresholdDialog, // Trigger dialog in parent
          ),

          // Flashlight Toggle Button
          IconButton(
            icon: Icon(
              flashlightService.isFlashlightOn
                  ? Icons.flashlight_on_outlined
                  : Icons.flashlight_off_outlined,
              size: 28,
            ),
            color: flashlightService.isFlashlightOn ? Colors.yellowAccent : timerColor,
            tooltip: flashlightService.isFlashlightOn
                ? 'Turn Flashlight Off'
                : 'Turn Flashlight On',
            onPressed: () => context.read<FlashlightService>().toggleFlashlight(),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(50.0);
}
// widgets/timer_control_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/timer_service.dart';
import 'package:myapp/providers/flashlight_service.dart';

class TimerControlBar extends StatelessWidget implements PreferredSizeWidget {
  final Color backgroundColor;
  final VoidCallback onTapDigits;

  const TimerControlBar({
    super.key,
    required this.backgroundColor,
    required this.onTapDigits,
  });

  Color _digitColor(TimerService service) {
    final remaining = service.remainingSecondsNotifier.value;
    final threshold = service.lightThresholdSeconds;
    final running = service.isTimerRunning;

    if (remaining <= 0) return Colors.red.shade500;
    if (running && remaining <= threshold) return Colors.orange.shade400;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final timerService = context.watch<TimerService>();
    final flashlightService = context.watch<FlashlightService>();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              timerService.isTimerRunning
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 30,
            ),
            color: Colors.white,
            tooltip: timerService.isTimerRunning ? 'Pause Timer' : 'Start Timer',
            onPressed: timerService.isTimerRunning
                ? () => context.read<TimerService>().pauseTimer()
                : () => context.read<TimerService>().startTimer(),
          ),

          GestureDetector(
            onTap: onTapDigits,
            child: ValueListenableBuilder<int>(
              valueListenable: timerService.remainingSecondsNotifier,
              builder: (context, remainingSeconds, child) => Text(
                timerService.formatDuration(remainingSeconds),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _digitColor(timerService),
                ),
              ),
            ),
          ),

          IconButton(
            icon: Icon(Icons.replay, size: 28),
            color: Colors.white,
            tooltip: 'Reset Timer',
            onPressed: () => context.read<TimerService>().resetAndStopTimer(),
          ),

          IconButton(
            icon: Icon(
              flashlightService.isFlashlightOn
                  ? Icons.flashlight_on_outlined
                  : Icons.flashlight_off_outlined,
              size: 28,
            ),
            color: flashlightService.isFlashlightOn ? Colors.yellowAccent : Colors.white,
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
  Size get preferredSize => const Size.fromHeight(44.0);
}
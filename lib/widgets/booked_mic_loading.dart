import 'package:flutter/material.dart';

/// Branded loading indicator that shows "Booked Mic" with a smooth
/// color-shifting animation through the app's blue‑to‑purple brand palette.
///
/// Usage:
/// ```dart
/// // Full branded loading screen
/// const BookedMicLoading()
///
/// // Compact version for button loading states
/// const BookedMicLoading(compact: true)
/// ```
class BookedMicLoading extends StatefulWidget {
  /// Text size for the full branded loading screen. Default 28.
  final double fontSize;

  /// If true, renders a compact colored spinner suitable for buttons and tight
  /// spaces instead of the full "Booked Mic" text.
  final bool compact;

  /// Size of the compact spinner (width & height). Default 24.
  final double compactSize;

  const BookedMicLoading({
    super.key,
    this.fontSize = 28,
    this.compact = false,
    this.compactSize = 24,
  });

  @override
  State<BookedMicLoading> createState() => _BookedMicLoadingState();
}

class _BookedMicLoadingState extends State<BookedMicLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  /// Four‑stage brand palette: blue → light blue → purple → deep purple
  static const List<Color> _palette = [
    Color(0xFF42A5F5), // blue.shade400  — primary brand
    Color(0xFF90CAF9), // blue.shade200
    Color(0xFFCE93D8), // purple.shade200
    Color(0xFFAB47BC), // purple.shade400
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = _controller.drive(
      TweenSequence<Color?>([
        TweenSequenceItem(
          tween: ColorTween(begin: _palette[0], end: _palette[1]),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: _palette[1], end: _palette[2]),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: _palette[2], end: _palette[3]),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: _palette[3], end: _palette[0]),
          weight: 1,
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      // Small colored spinner for buttons / inline loading
      return AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return SizedBox(
            width: widget.compactSize,
            height: widget.compactSize,
            child: CircularProgressIndicator(
              color: _colorAnimation.value,
              strokeWidth: 3,
            ),
          );
        },
      );
    }

    // Full branded loading screen with color‑shifting "Booked Mic"
    return Center(
      child: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Text(
            'Booked Mic',
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
              color: _colorAnimation.value,
              letterSpacing: 1.2,
            ),
          );
        },
      ),
    );
  }
}

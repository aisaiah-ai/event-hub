import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable rolling animated counter for metric tiles.
/// Animates on first load (0 → value) and when value increases; snaps when unchanged or decreased.
/// No AnimationController / TickerProvider; safe for rebuilds.
class RollingCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final bool enableGlow;
  final bool showDelta;
  /// Exaggerated mode: longer-feel curve, scale pulse, stronger glow. Makes the animation very visible.
  final bool exaggerated;

  const RollingCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 600),
    this.style,
    this.enableGlow = false,
    this.showDelta = false,
    this.exaggerated = false,
  });

  @override
  State<RollingCounter> createState() => _RollingCounterState();
}

class _RollingCounterState extends State<RollingCounter> {
  int _previousValue = 0;
  bool _shouldGlow = false;
  int _delta = 0;
  bool _showDelta = false;
  int? _syncScheduledForTarget;

  @override
  void didUpdateWidget(covariant RollingCounter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value > oldWidget.value) {
      _previousValue = oldWidget.value;
      _delta = widget.value - oldWidget.value;
      if (widget.enableGlow) {
        _triggerGlow();
      }
      if (widget.showDelta && _delta > 0) {
        _showDeltaIndicator();
      }
    } else if (widget.value < oldWidget.value) {
      _previousValue = widget.value;
    }
    // When value unchanged: do nothing so in-progress animation is not killed
  }

  void _triggerGlow() {
    setState(() => _shouldGlow = true);
    final glowDuration = widget.exaggerated
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 600);
    Future.delayed(glowDuration, () {
      if (mounted) setState(() => _shouldGlow = false);
    });
  }

  void _showDeltaIndicator() {
    setState(() => _showDelta = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showDelta = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.value > _previousValue;
    final duration = animate ? widget.duration : Duration.zero;
    final curve = widget.exaggerated ? Curves.elasticOut : Curves.easeOut;
    final begin = _previousValue.toDouble();
    final end = widget.value.toDouble();
    final span = end - begin;

    // Schedule one-time sync of _previousValue when this animation completes (so next rebuild doesn't re-run it).
    if (animate && duration > Duration.zero) {
      final target = widget.value;
      if (_syncScheduledForTarget != target) {
        _syncScheduledForTarget = target;
        Future.delayed(duration, () {
          if (mounted && widget.value == target) {
            setState(() {
              _previousValue = widget.value;
              _syncScheduledForTarget = null;
            });
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey('$_previousValue-${widget.value}'),
          tween: Tween<double>(begin: 0, end: 1),
          duration: duration,
          curve: curve,
          builder: (context, t, child) {
            final value = (begin + span * t).round();
            final scale = widget.exaggerated && animate
                ? 1.0 + 0.18 * math.sin(math.pi * t)
                : 1.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                boxShadow: _shouldGlow
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(widget.exaggerated ? 0.7 : 0.4),
                          blurRadius: widget.exaggerated ? 36 : 20,
                          spreadRadius: widget.exaggerated ? 8 : 2,
                        ),
                      ]
                    : [],
              ),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: Text(
                  NumberFormat.decimalPattern().format(value),
                  style: widget.style,
                ),
              ),
            );
          },
        ),
        if (widget.showDelta && _delta > 0) ...[
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: _showDelta ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Text(
              '+$_delta in last update',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: (widget.style?.color ?? Colors.black54),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

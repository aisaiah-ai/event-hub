import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../theme/nlc_palette.dart';

/// Kiosk-grade animated action card with hover, press scale, and elevation.
class AnimatedCheckinCard extends StatefulWidget {
  const AnimatedCheckinCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
    this.backgroundColor,
    this.isPrimary = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? backgroundColor;
  final bool isPrimary;

  @override
  State<AnimatedCheckinCard> createState() => _AnimatedCheckinCardState();
}

class _AnimatedCheckinCardState extends State<AnimatedCheckinCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  // DEBUG: Exaggerated values (0.85, -10, 40) to verify animation fires.
  // Revert to 0.97, -2, 28 when confirmed working.
  double get _scale => _isPressed ? 0.85 : 1.0;
  double get _translateY => _isHovered && kIsWeb ? -10.0 : 0.0;

  BoxShadow get _normalShadow => BoxShadow(
        color: Colors.black.withOpacity(0.25),
        blurRadius: 16,
        offset: const Offset(0, 8),
      );

  BoxShadow get _hoverShadow => BoxShadow(
        color: Colors.black.withOpacity(0.40),
        blurRadius: 40,
        offset: const Offset(0, 14),
      );

  void _onTapDown(TapDownDetails _) {
    debugPrint('AnimatedCheckinCard: Pressed down');
    if (!_isPressed) setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    debugPrint('AnimatedCheckinCard: Released');
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    debugPrint('AnimatedCheckinCard: Canceled');
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasGradient = widget.gradient != null;
    final bgColor = widget.backgroundColor;
    assert(
      hasGradient || (bgColor != null),
      'AnimatedCheckinCard requires gradient or backgroundColor',
    );

    final titleColor = widget.isPrimary ? NlcPalette.cream : NlcPalette.ink;
    final subtitleColor = widget.isPrimary ? NlcPalette.cream.withValues(alpha: 0.9) : NlcPalette.muted;
    final leadingColor = widget.isPrimary ? NlcPalette.cream : NlcPalette.brandBlueDark;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      cursor: SystemMouseCursors.click,
      onEnter: kIsWeb ? (_) => setState(() => _isHovered = true) : null,
      onExit: kIsWeb ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _scale,
          duration: Duration(milliseconds: _isPressed ? 90 : 120),
          curve: _isPressed ? Curves.easeIn : Curves.easeOut,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _translateY, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.black12,
                highlightColor: Colors.black.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: hasGradient ? widget.gradient! : null,
                    color: !hasGradient ? bgColor : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      _isHovered && kIsWeb ? _hoverShadow : _normalShadow,
                    ],
                  ),
                  child: Row(
                    children: [
                      IconTheme(
                        data: IconThemeData(color: leadingColor),
                        child: widget.leading,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: widget.isPrimary ? 18 : 16,
                                fontWeight:
                                    widget.isPrimary ? FontWeight.w700 : FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: widget.isPrimary ? 14 : 13,
                                fontWeight: FontWeight.w400,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

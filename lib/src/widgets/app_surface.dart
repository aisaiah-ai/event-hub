import 'package:flutter/material.dart';

/// Reusable surface for content sections with consistent depth and border.
/// Used for stats/topics/quote grouping and other layered content.
class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child, this.padding, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  static const EdgeInsets _defaultPadding = EdgeInsets.symmetric(
    horizontal: 28,
    vertical: 28,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? _defaultPadding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.27),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );
  }
}

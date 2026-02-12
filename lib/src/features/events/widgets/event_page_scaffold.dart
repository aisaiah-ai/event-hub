import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/event_model.dart';
import '../event_tokens.dart';

/// Scaffold for event pages with dynamic branding: background and logo.
/// Uses [EventModel] branding when provided, otherwise defaults.
class EventPageScaffold extends StatelessWidget {
  const EventPageScaffold({
    super.key,
    this.event,
    this.body,
    this.appBar,
  });

  final EventModel? event;
  final Widget? body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final primary = event?.primaryColor ?? EventTokens.primaryBlue;

    return Scaffold(
      backgroundColor: primary,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(primary),
          body ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildBackground(Color primary) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient base
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(primary, Colors.white, 0.08) ?? primary,
                primary,
                Color.lerp(primary, Colors.black, 0.15) ?? primary,
              ],
            ),
          ),
        ),
        // Optional full background image
        if (event?.backgroundImageUrl != null && event!.backgroundImageUrl!.isNotEmpty)
          _buildBackgroundImage(event!.backgroundImageUrl!),
        // Pattern overlay (event-specific or default CFC mosaic)
        _buildPatternOverlay(
          event?.backgroundPatternUrl ?? 'assets/checkin/mossaic.svg',
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(String url) {
    if (_isAssetPath(url)) {
      return Image.asset(url, fit: BoxFit.cover);
    }
    return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, e, st) => const SizedBox.expand());
  }

  Widget _buildPatternOverlay(String url) {
    final opacity = 0.06;
    if (_isAssetPath(url)) {
      return Opacity(
        opacity: opacity,
        child: SvgPicture.asset(url, fit: BoxFit.cover),
      );
    }
    if (url.endsWith('.svg')) {
      return Opacity(
        opacity: opacity,
        child: SvgPicture.network(url, fit: BoxFit.cover),
      );
    }
    return Opacity(
      opacity: opacity,
      child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, e, st) => const SizedBox.expand()),
    );
  }

  bool _isAssetPath(String path) => path.startsWith('assets/');
}

/// Logo widget for event branding. Supports asset paths and network URLs.
class EventLogo extends StatelessWidget {
  const EventLogo({
    super.key,
    this.logoUrl,
    this.size = 96,
  });

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl ?? 'assets/checkin/IntheOne.svg';
    if (url.isEmpty) return const SizedBox.shrink();

    if (_isAssetPath(url)) {
      if (url.endsWith('.svg')) {
        return SizedBox(
          height: size,
          width: size,
          child: SvgPicture.asset(url, fit: BoxFit.contain),
        );
      }
      return SizedBox(
        height: size,
        width: size,
        child: Image.asset(url, fit: BoxFit.contain),
      );
    }

    if (url.endsWith('.svg')) {
      return SizedBox(
        height: size,
        width: size,
        child: SvgPicture.network(url, fit: BoxFit.contain),
      );
    }
    return SizedBox(
      height: size,
      width: size,
      child: Image.network(url, fit: BoxFit.contain),
    );
  }

  bool _isAssetPath(String path) => path.startsWith('assets/');
}

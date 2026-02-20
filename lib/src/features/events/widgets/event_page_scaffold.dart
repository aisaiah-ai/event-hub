import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/nlc_theme.dart';
import '../../../theme/nlc_palette.dart';
import '../data/event_model.dart';

/// Scaffold for event pages with dynamic branding: background and logo.
/// Uses [EventModel] branding when provided, otherwise defaults.
class EventPageScaffold extends StatelessWidget {
  const EventPageScaffold({
    super.key,
    this.event,
    this.eventSlug,
    this.body,
    this.appBar,
    /// Override max width for body (e.g. 1200 for dashboard). Default 520 for NLC.
    this.bodyMaxWidth,
    /// Override overlay opacity for NLC background (default 0.55).
    this.overlayOpacity,
    /// Override overlay tint color (default brandBlueDark).
    this.overlayTint,
    /// Use radial overlay (subtle top glow) for immersive main check-in. Ignored if useLightBackground.
    this.useRadialOverlay = false,
    /// Use light executive background (no image/overlay). For analytics dashboard.
    this.useLightBackground = false,
  });

  final EventModel? event;
  /// Route param (e.g. 'nlc') used for background fallback when event is loading.
  final String? eventSlug;
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final double? bodyMaxWidth;
  final double? overlayOpacity;
  final Color? overlayTint;
  final bool useRadialOverlay;
  final bool useLightBackground;

  @override
  Widget build(BuildContext context) {
    if (useLightBackground) {
      return Scaffold(
        backgroundColor: NlcColors.ivory,
        appBar: appBar,
        body: body != null
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bodyMaxWidth ?? 1200),
                  child: body,
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    final primary = event?.primaryColor ?? NlcColors.primaryBlue;
    final bgUrl = _effectiveBackgroundImageUrl();
    final useNlcLocalAsset = bgUrl == EventPageScaffold.nlcBackgroundAsset;

    final overlay = overlayOpacity ?? 0.55;
    final maxW = bodyMaxWidth ?? 520.0;

    return Scaffold(
      backgroundColor: bgUrl != null ? Colors.transparent : primary,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: useNlcLocalAsset
          ? Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    EventPageScaffold.nlcBackgroundAsset,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: useRadialOverlay
                          ? RadialGradient(
                              center: Alignment.topCenter,
                              radius: 0.8,
                              colors: [
                                NlcPalette.brandBlueSoft.withValues(alpha: 0.25),
                                (overlayTint ?? NlcPalette.brandBlueDark),
                              ],
                            )
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (overlayTint ?? NlcPalette.brandBlueDark).withValues(alpha: overlay),
                                (overlayTint ?? NlcPalette.brandBlueDark).withValues(alpha: overlay * 0.85),
                              ],
                            ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: body ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [_buildBackground(primary), body ?? const SizedBox.shrink()],
            ),
    );
  }

  /// NLC 2026: local asset only (weekend-safe). No network images.
  static const String nlcBackgroundAsset = 'assets/images/nlc_background.png';

  String? _effectiveBackgroundImageUrl() {
    var url = event?.backgroundImageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.contains('background2.svg')) return nlcBackgroundAsset;
      return url;
    }
    final slug = event?.slug ?? eventSlug;
    if (slug == 'nlc' ||
        slug == 'nlc-2026' ||
        (event?.name.toLowerCase().contains('national leaders conference') ?? false))
      return nlcBackgroundAsset;
    return null;
  }

  Widget _buildBackground(Color primary) {
    final bgUrl = _effectiveBackgroundImageUrl();
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient base (skip when using full background image)
        if (bgUrl == null)
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
        // Optional full background image (NLC fallback when slug is 'nlc')
        if (bgUrl case final url?)
          _buildBackgroundImage(url),
        // Pattern overlay (skip when using full background image; it often has its own pattern)
        if (bgUrl == null)
          _buildPatternOverlay(
            event?.backgroundPatternUrl ?? 'assets/checkin/mossaic.svg',
          ),
      ],
    );
  }

  Widget _buildBackgroundImage(String url) {
    if (url.toLowerCase().endsWith('.svg')) {
      if (_isAssetPath(url)) {
        return Positioned.fill(
          child: SvgPicture.asset(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      }
      return Positioned.fill(
        child: SvgPicture.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholderBuilder: (_) => const SizedBox.expand(),
        ),
      );
    }
    if (_isAssetPath(url)) {
      return Positioned.fill(
        child: Image.asset(url, fit: BoxFit.cover),
      );
    }
    return Positioned.fill(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, e, st) => const SizedBox.expand(),
      ),
    );
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
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, e, st) => const SizedBox.expand(),
      ),
    );
  }

  bool _isAssetPath(String path) => path.startsWith('assets/');
}

/// Logo widget for event branding. Supports asset paths and network URLs.
class EventLogo extends StatelessWidget {
  const EventLogo({super.key, this.logoUrl, this.size = 96});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = logoUrl ?? 'assets/checkin/nlc_logo.png';
    final url = raw == 'assets/checkin/empower.png' ? 'assets/checkin/nlc_logo.png' : raw;
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

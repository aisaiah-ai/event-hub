import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Smart Event Landing Page — shown when a user scans a QR code or taps NFC
/// and the AIsaiah mobile app does not automatically open.
///
/// Route: /s/:shortCode (e.g., /s/mca)
///
/// Flow:
/// 1. Auto-attempts to open the AIsaiah app via deep link
/// 2. If app doesn't open, shows install prompts + browser fallback
/// 3. Encourages app installation while never blocking browser access
class SmartEventLandingPage extends StatefulWidget {
  const SmartEventLandingPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<SmartEventLandingPage> createState() => _SmartEventLandingPageState();
}

enum _AppOpenStatus { initial, attempting, fallback }

class _SmartEventLandingPageState extends State<SmartEventLandingPage> {
  _AppOpenStatus _status = _AppOpenStatus.initial;
  bool _didAutoAttempt = false;

  @override
  void initState() {
    super.initState();
    // Auto-attempt to open the app after a brief delay to let the page render
    Future.delayed(const Duration(milliseconds: 300), _autoAttemptOpen);
  }

  /// Auto-attempt deep link open on page load.
  Future<void> _autoAttemptOpen() async {
    if (_didAutoAttempt || !mounted) return;
    _didAutoAttempt = true;
    setState(() => _status = _AppOpenStatus.attempting);

    await _attemptOpenInApp();

    // After ~1.8s, if we're still here the app didn't open — show fallback
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted && _status == _AppOpenStatus.attempting) {
      setState(() => _status = _AppOpenStatus.fallback);
    }
  }

  /// Attempt to open the AIsaiah app via deep link.
  Future<void> _attemptOpenInApp() async {
    // TODO: Replace with your actual deep link scheme and universal link
    // The deep link scheme from Cloud Functions is: aisaiah://event/{eventId}
    final deepLink = Uri.parse('aisaiah://event/${widget.eventSlug}');

    try {
      final launched = await launchUrl(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('[SmartLanding] Deep link not launched: $deepLink');
      }
    } catch (e) {
      debugPrint('[SmartLanding] Deep link error: $e');
    }
  }

  /// Manual tap on "Open in App" button.
  void _openInApp() {
    setState(() => _status = _AppOpenStatus.attempting);
    _attemptOpenInApp().then((_) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _status == _AppOpenStatus.attempting) {
          setState(() => _status = _AppOpenStatus.fallback);
        }
      });
    });
  }

  void _openAppStore() {
    // TODO: Replace with actual App Store URL
    // launchUrl(Uri.parse('https://apps.apple.com/app/aisaiah/id...'));
    debugPrint('[SmartLanding] openAppStore');
  }

  void _openPlayStore() {
    // TODO: Replace with actual Play Store URL
    // launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=...'));
    debugPrint('[SmartLanding] openPlayStore');
  }

  void _continueInBrowser() {
    context.go('/events/${widget.eventSlug}');
  }

  void _openCampaign() {
    // TODO: Replace with actual ANCOP campaign URL
    // launchUrl(Uri.parse('https://ancop.org/campaigns/...'));
    debugPrint('[SmartLanding] openCampaign');
  }

  @override
  Widget build(BuildContext context) {
    final isAttempting = _status == _AppOpenStatus.attempting;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // ── Background ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/march_assembly_background.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _bgDark.withValues(alpha: 0.70),
                    _bgDark.withValues(alpha: 0.92),
                    _bgDark,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Mosaic corner decorations
          Positioned(
            top: -40,
            right: -40,
            child: _MosaicCorner(alignment: Alignment.topRight),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: _MosaicCorner(alignment: Alignment.bottomLeft),
          ),

          // ── Content ──
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      // Section 1: Event Header
                      const _EventHeader(),
                      const SizedBox(height: 28),

                      // Value message
                      Text(
                        'Install the app to check in faster, follow the live schedule, and share photos.',
                        style: GoogleFonts.inter(
                          color: _textWhite.withValues(alpha: 0.65),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Status text + Primary CTA
                      _AppOpenStatusText(status: _status),
                      const SizedBox(height: 14),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 420,
                            height: 160,
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Color(0x1AFFB84D),
                                  Color(0x0DFFB84D),
                                  Colors.transparent,
                                ],
                                radius: 1.2,
                              ),
                            ),
                          ),
                          _PrimaryCTA(
                            isAttempting: isAttempting,
                            onTap: _openInApp,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Social proof
                      const _SocialProofRow(
                        checkedInCount: 63,
                        photosSharedCount: 12,
                      ),
                      const SizedBox(height: 32),

                      // Section 7: Live preview (optional)
                      const _LivePreviewCard(),
                      const SizedBox(height: 32),

                      // Section 3: Feature Cards
                      const _FeatureSection(),
                      const SizedBox(height: 32),

                      // Section 4: Campaign Card
                      _CampaignHighlightCard(onTap: _openCampaign),
                      const SizedBox(height: 32),

                      // Section 5: App Store Buttons
                      _AppStoreSection(
                        onAppStore: _openAppStore,
                        onPlayStore: _openPlayStore,
                      ),
                      const SizedBox(height: 28),

                      // Section 6: Continue in Browser
                      _ContinueInBrowserLink(onTap: _continueInBrowser),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Colors ──────────────────────────────────────────────────────────────────

const _bgDark = Color(0xFF0A0A14);
const _gold = Color(0xFFF4A340);
const _goldLight = Color(0xFFFFD88A);
const _goldDim = Color(0xFF8B6B2F);
const _cardBg = Color(0xFF12121E);
const _liveGreen = Color(0xFF7AE3A5);
const _textWhite = Colors.white;
const _textMuted = Color(0xFF8888A0);

// ─── Section 1: Event Header ─────────────────────────────────────────────────

class _EventHeader extends StatelessWidget {
  const _EventHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Organization label
        Text(
          'MARCH CLUSTER ASSEMBLY',
          style: GoogleFonts.inter(
            color: _gold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Evangelization Rally & Fellowship Night',
          style: GoogleFonts.inter(
            color: _textWhite.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const _GoldDivider(),
        const SizedBox(height: 20),
        // Large title
        Text(
          'March Cluster\nAssembly',
          style: GoogleFonts.inter(
            color: _textWhite,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Evangelization Rally & Fellowship Night',
          style: GoogleFonts.inter(
            color: _textWhite.withValues(alpha: 0.75),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const _GoldDivider(),
        const SizedBox(height: 16),
        // Metadata row
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          children: [
            Text(
              'March 14',
              style: GoogleFonts.inter(
                color: _textWhite.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '\u2022',
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ),
            Text(
              'St. Michael\'s Hall',
              style: GoogleFonts.inter(
                color: _textWhite.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            // LIVE badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _liveGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _liveGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulsingDot(),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: GoogleFonts.inter(
                      color: _liveGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Pulsing Live Dot ────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: _liveGreen,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Section 2: App Open Status Text ─────────────────────────────────────────

class _AppOpenStatusText extends StatelessWidget {
  const _AppOpenStatusText({required this.status});
  final _AppOpenStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _AppOpenStatus.initial:
        return Text(
          'Tap below to open the event in the AIsaiah App',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: _textWhite.withValues(alpha: 0.7),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        );
      case _AppOpenStatus.attempting:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _gold.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Opening AIsaiah App...',
              style: GoogleFonts.inter(
                color: _gold.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case _AppOpenStatus.fallback:
        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              color: _textWhite.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'App not opening? '),
              TextSpan(
                text: 'Install it below',
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' or continue in browser.'),
            ],
          ),
        );
    }
  }
}

// ─── Section 2: Primary App Open Button ─────────────────────────────────────

/// Premium CTA button with pulsing glow, shimmer, hover scale, and press feedback.
class _PrimaryCTA extends StatefulWidget {
  const _PrimaryCTA({required this.isAttempting, required this.onTap});

  final bool isAttempting;
  final VoidCallback onTap;

  @override
  State<_PrimaryCTA> createState() => _PrimaryCTAState();
}

class _PrimaryCTAState extends State<_PrimaryCTA>
    with TickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  late final AnimationController _glowController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // Ambient glow pulse — always running
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Shimmer sweep every 4 seconds
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _startShimmerLoop();
  }

  void _startShimmerLoop() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 4000));
      if (!mounted) return;
      _shimmerController.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(_PrimaryCTA old) {
    super.didUpdateWidget(old);
    // Speed up glow when attempting
    if (widget.isAttempting && !old.isAttempting) {
      _glowController.duration = const Duration(milliseconds: 1200);
      _glowController.repeat(reverse: true);
    } else if (!widget.isAttempting && old.isAttempting) {
      _glowController.duration = const Duration(milliseconds: 2400);
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowController, _shimmerController]),
      builder: (context, child) {
        final glow = _glowController.value;
        final shimmer = _shimmerController.value;

        // Glow intensity
        final baseGlow = widget.isAttempting ? 0.20 : 0.12;
        final glowAlpha = _hovered ? 0.40 : (baseGlow + glow * 0.12);
        final blurRadius = _hovered ? 34.0 : (16.0 + glow * 12);
        final spreadRadius = _hovered ? 3.0 : (glow * 1.5);

        // Scale: hover 1.03, press 0.97
        final scale = _pressed ? 0.97 : (_hovered ? 1.03 : 1.0);

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 44),
                decoration: BoxDecoration(
                  color: _hovered
                      ? _gold.withValues(alpha: 0.15)
                      : _bgDark.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: _hovered || widget.isAttempting
                        ? _gold
                        : _goldDim.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: glowAlpha),
                      blurRadius: blurRadius,
                      spreadRadius: spreadRadius,
                    ),
                    BoxShadow(
                      color: const Color(0xFF4CE0C6).withValues(alpha: 0.06),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(48),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Shimmer sweep
                      if (shimmer > 0 && shimmer < 1)
                        Positioned(
                          left: -60 + (shimmer * 400),
                          child: Container(
                            width: 60,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _goldLight.withValues(alpha: 0.08),
                                  _goldLight.withValues(alpha: 0.15),
                                  _goldLight.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Content
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isAttempting) ...[
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _goldLight.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else ...[
                            Icon(
                              Icons.phone_iphone_rounded,
                              color: _goldLight,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.isAttempting
                                ? 'OPENING AISAIAH APP...'
                                : 'OPEN IN AISAIAH APP',
                            style: GoogleFonts.inter(
                              color: _goldLight,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Social Proof Row ────────────────────────────────────────────────────────

class _SocialProofRow extends StatelessWidget {
  const _SocialProofRow({
    required this.checkedInCount,
    required this.photosSharedCount,
  });

  /// TODO: Connect to live Firestore check-in count stream
  final int checkedInCount;

  /// TODO: Connect to live Firestore photos count stream
  final int photosSharedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _proofPill(Icons.people_outline_rounded, '$checkedInCount checked in'),
        const SizedBox(width: 12),
        _proofPill(
          Icons.camera_alt_outlined,
          '$photosSharedCount photos shared',
        ),
      ],
    );
  }

  Widget _proofPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _textWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _textWhite.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _textMuted.withValues(alpha: 0.7), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: _textMuted.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live Preview Card (Optional) ────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _liveGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Pulse dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _liveGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _liveGreen.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HAPPENING NOW',
                  style: GoogleFonts.inter(
                    color: _liveGreen.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Worship & Praise',
                  style: GoogleFonts.inter(
                    color: _textWhite.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '4:05 PM',
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: _textMuted.withValues(alpha: 0.4),
            size: 12,
          ),
        ],
      ),
    );
  }
}

// ─── Section 3: Feature Cards ────────────────────────────────────────────────

class _FeatureSection extends StatelessWidget {
  const _FeatureSection();

  static const _features = [
    _FeatureData(
      Icons.calendar_today_rounded,
      'Live Schedule',
      "See what's happening now and what's next",
      iconSize: 28,
    ),
    _FeatureData(
      Icons.check_circle_outline,
      'Fast Check-In',
      'Get checked in quickly at the event',
      iconSize: 30,
    ),
    _FeatureData(
      Icons.camera_alt_outlined,
      'Upload Photos',
      'Share moments with the community',
      iconSize: 29,
      yOffset: 1,
    ),
    _FeatureData(
      Icons.notifications_none,
      'Event Updates',
      'Receive updates during the event',
      iconSize: 30,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Why use the app?',
          style: GoogleFonts.inter(
            color: _textWhite.withValues(alpha: 0.9),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            if (isWide) {
              return Row(
                children: _features
                    .map(
                      (f) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _FeatureCard(
                            icon: f.icon,
                            title: f.title,
                            description: f.description,
                            iconSize: f.iconSize,
                            yOffset: f.yOffset,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            }
            // 2x2 grid for mobile/tablet
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _features
                  .map(
                    (f) => SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _FeatureCard(
                        icon: f.icon,
                        title: f.title,
                        description: f.description,
                        iconSize: f.iconSize,
                        yOffset: f.yOffset,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FeatureData {
  const _FeatureData(
    this.icon,
    this.title,
    this.description, {
    this.iconSize = 28,
    this.yOffset = 0,
  });
  final IconData icon;
  final String title;
  final String description;
  final double iconSize;
  final double yOffset;
}

class _FeatureIconContainer extends StatelessWidget {
  const _FeatureIconContainer({
    required this.icon,
    this.iconSize = 28,
    this.yOffset = 0,
  });

  final IconData icon;
  final double iconSize;
  final double yOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF2A1E14).withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Transform.translate(
        offset: Offset(0, yOffset),
        child: Icon(icon, size: iconSize, color: const Color(0xFFFFB84D)),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.iconSize = 28,
    this.yOffset = 0,
  });

  final IconData icon;
  final String title;
  final String description;
  final double iconSize;
  final double yOffset;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: _hovered ? 0.9 : 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? _gold.withValues(alpha: 0.35)
                : _goldDim.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.35 : 0.2),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
            if (_hovered)
              BoxShadow(color: _gold.withValues(alpha: 0.06), blurRadius: 16),
          ],
        ),
        child: Column(
          children: [
            _FeatureIconContainer(
              icon: widget.icon,
              iconSize: widget.iconSize,
              yOffset: widget.yOffset,
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                color: _textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section 4: Campaign Highlight Card (reduced weight) ─────────────────────

class _CampaignHighlightCard extends StatelessWidget {
  const _CampaignHighlightCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _goldDim.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community Campaign label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE04C6D).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: const Color(0xFFE04C6D).withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFE04C6D), size: 12),
                const SizedBox(width: 5),
                Text(
                  'COMMUNITY CAMPAIGN',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE04C6D),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 400;
              if (isWide) {
                return Row(
                  children: [
                    _campaignPortrait(),
                    const SizedBox(width: 14),
                    Expanded(child: _campaignContent()),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _campaignPortrait(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Bro Art's Big 70th Birthday ANCOP Campaign",
                          style: GoogleFonts.inter(
                            color: _textWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _campaignSubtitle(),
                  const SizedBox(height: 10),
                  _campaignButton(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _campaignPortrait() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/art_barlaan.jpg',
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF3E7D4C).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              'AB',
              style: GoogleFonts.inter(
                color: _textWhite,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campaignContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bro Art's Big 70th\nANCOP Campaign",
          style: GoogleFonts.inter(
            color: _textWhite,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        _campaignSubtitle(),
        const SizedBox(height: 10),
        _campaignButton(),
      ],
    );
  }

  Widget _campaignSubtitle() {
    return Text(
      'A personal campaign sponsored by Arthur Barlaan',
      style: GoogleFonts.inter(
        color: _textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
  }

  Widget _campaignButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, color: _gold, size: 14),
            const SizedBox(width: 6),
            Text(
              'Support This Campaign',
              style: GoogleFonts.inter(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section 5: App Store Buttons ────────────────────────────────────────────

class _AppStoreSection extends StatelessWidget {
  const _AppStoreSection({required this.onAppStore, required this.onPlayStore});

  final VoidCallback onAppStore;
  final VoidCallback onPlayStore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 450;
        final badges = [
          _StoreBadge(
            assetPath: 'assets/images/badge_appstore.png',
            onTap: onAppStore,
          ),
          _StoreBadge(
            assetPath: 'assets/images/badge_googleplay.png',
            onTap: onPlayStore,
          ),
        ];

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [badges[0], const SizedBox(width: 16), badges[1]],
          );
        }
        return Column(
          children: [badges[0], const SizedBox(height: 12), badges[1]],
        );
      },
    );
  }
}

class _StoreBadge extends StatefulWidget {
  const _StoreBadge({required this.assetPath, required this.onTap});

  final String assetPath;
  final VoidCallback onTap;

  @override
  State<_StoreBadge> createState() => _StoreBadgeState();
}

class _StoreBadgeState extends State<_StoreBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _hovered ? 1.0 : 0.85,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              widget.assetPath,
              height: 54,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(height: 54, width: 180),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section 6: Continue in Browser ──────────────────────────────────────────

class _ContinueInBrowserLink extends StatefulWidget {
  const _ContinueInBrowserLink({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ContinueInBrowserLink> createState() => _ContinueInBrowserLinkState();
}

class _ContinueInBrowserLinkState extends State<_ContinueInBrowserLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? _textWhite.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue in browser',
                style: GoogleFonts.inter(
                  color: _hovered
                      ? _textWhite.withValues(alpha: 0.75)
                      : _textMuted.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: _hovered
                    ? _textWhite.withValues(alpha: 0.6)
                    : _textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Decorative Widgets ──────────────────────────────────────────────────────

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _goldDim.withValues(alpha: 0.5)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.auto_awesome,
            color: _goldDim.withValues(alpha: 0.5),
            size: 12,
          ),
        ),
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_goldDim.withValues(alpha: 0.5), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

class _MosaicCorner extends StatelessWidget {
  const _MosaicCorner({required this.alignment});
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTopRight = alignment == Alignment.topRight;
    return Transform.rotate(
      angle: isTopRight ? 0.0 : 3.14159,
      child: ShaderMask(
        shaderCallback: (bounds) => RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            _gold.withValues(alpha: 0.25),
            _gold.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: CustomPaint(painter: _MosaicPainter()),
        ),
      ),
    );
  }
}

class _MosaicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const tileSize = 16.0;
    for (var x = 0.0; x < size.width; x += tileSize) {
      for (var y = 0.0; y < size.height; y += tileSize) {
        final dist = (x * x + y * y);
        final maxDist = size.width * size.width;
        if (dist < maxDist * 0.7) {
          final opacity = 1.0 - (dist / maxDist);
          paint.color = _gold.withValues(alpha: 0.15 * opacity);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x + 1, y + 1, tileSize - 2, tileSize - 2),
              const Radius.circular(2),
            ),
            paint,
          );
          if ((x.toInt() + y.toInt()) % 48 < 16) {
            final fillPaint = Paint()
              ..color = _gold.withValues(alpha: 0.06 * opacity)
              ..style = PaintingStyle.fill;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x + 1, y + 1, tileSize - 2, tileSize - 2),
                const Radius.circular(2),
              ),
              fillPaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/nlc_palette.dart';
import '../../../models/session.dart';
import '../../events/data/event_model.dart';
import '../../../core/theme/nlc_theme.dart';
import '../data/nlc_sessions.dart';
import 'theme/checkin_theme.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';
import 'widgets/location_block.dart';
import 'widgets/subtitle_bar.dart';

/// Session picker for NLC — choose one of 3 dialogue sessions.
/// Each session has its own check-in page and QR code.
class CheckinSessionPickerPage extends StatefulWidget {
  const CheckinSessionPickerPage({
    super.key,
    required this.event,
    required this.eventSlug,
  });

  final EventModel event;
  final String eventSlug;

  @override
  State<CheckinSessionPickerPage> createState() =>
      _CheckinSessionPickerPageState();
}

class _CheckinSessionPickerPageState extends State<CheckinSessionPickerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final eventSlug = widget.eventSlug;
    return SafeArea(
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.afterHeader),
                  ConferenceHeader(logoUrl: event.logoUrl),
                  const SizedBox(height: AppSpacing.betweenSections),
                  const SubtitleBar(),
                  const SizedBox(height: AppSpacing.belowSubtitle),
                  LocationBlock(
                    venue: event.locationName,
                    address: event.address,
                    decoration: BoxDecoration(
                      color: NlcColors.ivory,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    iconColor: NlcPalette.brandBlue,
                    venueStyle: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                    addressStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary87,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.betweenSections),
                  _ConferenceCheckinCard(
                    eventSlug: eventSlug,
                    decoration: _primaryCardDecoration,
                  ),
                  const SizedBox(height: AppSpacing.aboveSectionTitle),
                  _breakoutSessionsSection(context),
                  const SizedBox(height: AppSpacing.betweenSectionTitleAndCards),
                  _SessionCard(
                    session: NlcSessions.genderIdeology,
                    slug: NlcSessions.genderIdeologySlug,
                    eventSlug: eventSlug,
                    decoration: _sessionCardDecoration,
                  ),
                  const SizedBox(height: AppSpacing.betweenSecondaryCards),
                  _SessionCard(
                    session: NlcSessions.contraceptionIvfAbortion,
                    slug: NlcSessions.contraceptionIvfAbortionSlug,
                    eventSlug: eventSlug,
                    decoration: _sessionCardDecoration,
                  ),
                  const SizedBox(height: AppSpacing.betweenSecondaryCards),
                  _SessionCard(
                    session: NlcSessions.immigration,
                    slug: NlcSessions.immigrationSlug,
                    eventSlug: eventSlug,
                    decoration: _sessionCardDecoration,
                  ),
                  const SizedBox(height: AppSpacing.footerTop),
                  const FooterCredits(),
                  const SizedBox(height: AppSpacing.betweenSections),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _breakoutSessionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: NlcPalette.brandBlueSoft.withValues(alpha: 0.4),
        ),
        Text(
          'BREAKOUT SESSIONS',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: NlcColors.ivory,
          ),
        ),
      ],
    );
  }
}

const double _cardRadius = 20;

/// Elevated shadow for session tiles: blur 22, offset y 8.
final BoxShadow _elevatedCardShadow = BoxShadow(
  color: Colors.black.withValues(alpha: 0.25),
  blurRadius: 22,
  offset: const Offset(0, 8),
);

BoxDecoration get _sessionCardDecoration => BoxDecoration(
      color: NlcColors.ivory,
      borderRadius: BorderRadius.circular(_cardRadius),
      boxShadow: [_elevatedCardShadow],
    );

/// Primary "main gate" card: slightly taller, blue border, gradient, icon glow.
BoxDecoration get _primaryCardDecoration => BoxDecoration(
      color: NlcColors.ivory,
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(
        color: NlcPalette.brandBlue.withValues(alpha: 0.35),
        width: 1,
      ),
      boxShadow: [_elevatedCardShadow],
    );

class _ConferenceCheckinCard extends StatefulWidget {
  const _ConferenceCheckinCard({
    required this.eventSlug,
    this.decoration,
  });

  final String eventSlug;
  final BoxDecoration? decoration;

  @override
  State<_ConferenceCheckinCard> createState() => _ConferenceCheckinCardState();
}

class _ConferenceCheckinCardState extends State<_ConferenceCheckinCard> {
  bool _hovering = false;
  bool _pressing = false;

  static const double _iconSize = 28; // 15% larger than 24
  static const double _iconContainerSize = 56;

  static final BoxShadow _hoverShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.25),
    blurRadius: 16,
    offset: const Offset(0, 4),
  );

  @override
  Widget build(BuildContext context) {
    final base = widget.decoration ?? BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(_cardRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final effectiveDecoration = base.copyWith(
      boxShadow: [
        ...?base.boxShadow,
        if (_hovering) _hoverShadow,
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: () => context.go('/events/${widget.eventSlug}/main-checkin'),
        child: AnimatedScale(
          scale: _pressing ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.identity()..translate(0.0, _hovering ? -2.0 : 0.0),
            transformAlignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/events/${widget.eventSlug}/main-checkin'),
                borderRadius: BorderRadius.circular(_cardRadius),
                splashColor: NlcPalette.brandBlue.withValues(alpha: 0.25),
                highlightColor: NlcPalette.brandBlue.withValues(alpha: 0.1),
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: effectiveDecoration,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Subtle blue gradient overlay (top to bottom)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_cardRadius),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              NlcPalette.brandBlue.withValues(alpha: 0.06),
                              NlcPalette.brandBlue.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // Icon with soft glow
                        Container(
                          width: _iconContainerSize,
                          height: _iconContainerSize,
                          decoration: BoxDecoration(
                            color: NlcPalette.brandBlueSoft,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: NlcPalette.brandBlue.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: AppColors.navy,
                            size: _iconSize,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Conference Check-In',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Main Event Entry',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.navy.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: AppColors.chevronNavy,
                        ),
                      ],
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

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.session,
    required this.slug,
    required this.eventSlug,
    this.decoration,
  });

  final Session session;
  final String slug;
  final String eventSlug;
  final BoxDecoration? decoration;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _hovering = false;
  bool _pressing = false;

  static final BoxShadow _hoverShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.25),
    blurRadius: 22,
    offset: const Offset(0, 4),
  );

  @override
  Widget build(BuildContext context) {
    final base = widget.decoration ?? BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(_cardRadius),
      boxShadow: [_elevatedCardShadow],
    );
    final effectiveDecoration = base.copyWith(
      boxShadow: [
        ...?base.boxShadow,
        if (_hovering) _hoverShadow,
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: () => context.go(
          '/events/${widget.eventSlug}/checkin/${widget.slug}',
        ),
        child: AnimatedScale(
          scale: _pressing ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.identity()..translate(0.0, _hovering ? -2.0 : 0.0),
            transformAlignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(
                  '/events/${widget.eventSlug}/checkin/${widget.slug}',
                ),
                borderRadius: BorderRadius.circular(_cardRadius),
                splashColor: NlcPalette.brandBlue.withValues(alpha: 0.25),
                highlightColor: NlcPalette.brandBlue.withValues(alpha: 0.1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(20),
                  decoration: effectiveDecoration,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: NlcPalette.brandBlueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.navy,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.session.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.session.isActive)
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.liveBadgeGreen,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.liveBadgeGreen.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: AppColors.chevronNavy,
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

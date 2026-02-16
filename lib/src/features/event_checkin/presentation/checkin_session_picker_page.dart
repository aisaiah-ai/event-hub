import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/session.dart';
import '../../events/data/event_model.dart';
import '../data/nlc_sessions.dart';
import 'theme/checkin_theme.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';
import 'widgets/location_block.dart';
import 'widgets/subtitle_bar.dart';

/// Session picker for NLC — choose one of 3 dialogue sessions.
/// Each session has its own check-in page and QR code.
class CheckinSessionPickerPage extends StatelessWidget {
  const CheckinSessionPickerPage({
    super.key,
    required this.event,
    required this.eventSlug,
  });

  final EventModel event;
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                ),
                const SizedBox(height: AppSpacing.betweenSections),
                Text(
                  'Select your session',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.betweenSecondaryCards),
                _SessionCard(
                  session: NlcSessions.genderIdeology,
                  slug: NlcSessions.genderIdeologySlug,
                  eventSlug: eventSlug,
                ),
                const SizedBox(height: AppSpacing.betweenSecondaryCards),
                _SessionCard(
                  session: NlcSessions.contraceptionIvfAbortion,
                  slug: NlcSessions.contraceptionIvfAbortionSlug,
                  eventSlug: eventSlug,
                ),
                const SizedBox(height: AppSpacing.betweenSecondaryCards),
                _SessionCard(
                  session: NlcSessions.immigration,
                  slug: NlcSessions.immigrationSlug,
                  eventSlug: eventSlug,
                ),
                const SizedBox(height: AppSpacing.footerTop),
                const FooterCredits(),
                const SizedBox(height: AppSpacing.betweenSections),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.slug,
    required this.eventSlug,
  });

  final Session session;
  final String slug;
  final String eventSlug;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/events/$eventSlug/checkin/$slug'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.goldIconContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.navy,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  session.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.navy.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

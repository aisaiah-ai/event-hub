import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/session.dart';
import '../../../services/session_catalog_service.dart';
import '../../../theme/nlc_palette.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import '../data/nlc_sessions.dart';
import 'theme/checkin_theme.dart';
import '../../../core/theme/session_colors.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';
import 'session_selection_screen.dart';

/// Check-in gate for NLC: same session selection UI as preview and registrant flow.
/// Choose main check-in or a breakout session; navigates to the corresponding route.
class CheckinGatePage extends StatefulWidget {
  const CheckinGatePage({
    super.key,
    required this.event,
    required this.eventSlug,
  });

  final EventModel event;
  final String eventSlug;

  @override
  State<CheckinGatePage> createState() => _CheckinGatePageState();
}

class _CheckinGatePageState extends State<CheckinGatePage> {
  List<SessionWithAvailability> _breakoutSessions = [];
  bool _loading = true;
  String? _error;

  static const String _mainCheckInBlueHex = '#2E5E7E';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = SessionCatalogService();
      final list = await catalog.listSessionsWithAvailability(widget.event.id);
      if (!mounted) return;
      setState(() {
        _breakoutSessions = list
            .where((e) => e.session.id != NlcSessions.mainCheckInSessionId)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Session get _mainCheckInSession => Session(
        id: NlcSessions.mainCheckInSessionId,
        title: 'Conference Check-In',
        name: 'Conference Check-In',
        isActive: true,
        location: widget.event.locationName.isNotEmpty
            ? widget.event.locationName
            : widget.event.address,
        capacity: 0,
        attendanceCount: 0,
        colorHex: _mainCheckInBlueHex,
      );

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: widget.event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 520,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.afterHeader),
                    ConferenceHeader(logoUrl: widget.event.logoUrl),
                    const SizedBox(height: 18),
                    Text(
                      'Choose check-in',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: NlcPalette.cream.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Main entry or a breakout session.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.35,
                        color: NlcPalette.cream.withValues(alpha: 0.85),
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 18),
                    _buildMainCheckInCard(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(color: NlcPalette.cream),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.orange.shade200),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._breakoutSessions.map((item) {
                        final session = item.session;
                        final slug = NlcSessions.slugForSessionId(session.id);
                        if (slug == null) return const SizedBox.shrink();
                        final disabled = item.label == SessionAvailabilityLabel.full ||
                            item.label == SessionAvailabilityLabel.closed;
                        final color = resolveSessionColor(session);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SessionSelectionCard(
                            session: session,
                            remainingSeats: item.remainingSeats,
                            preRegisteredCount: item.preRegisteredCount,
                            label: item.label,
                            color: color,
                            onTap: disabled
                                ? null
                                : () => context.go(
                                      '/events/${widget.eventSlug}/checkin/$slug',
                                    ),
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.footerTop),
                    const FooterCredits(),
                    const SizedBox(height: AppSpacing.betweenSections),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCheckInCard() {
    final session = _mainCheckInSession;
    final color = resolveSessionColor(session);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SessionSelectionCard(
        session: session,
        remainingSeats: 0,
        preRegisteredCount: 0,
        label: SessionAvailabilityLabel.available,
        color: color,
        onTap: () => context.go('/events/${widget.eventSlug}/main-checkin'),
      ),
    );
  }
}

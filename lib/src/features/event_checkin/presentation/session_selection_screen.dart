import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/session.dart';
import '../../../services/checkin_orchestrator_service.dart';
import '../../../services/session_catalog_service.dart';
import '../../../theme/nlc_palette.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
import '../../../core/theme/session_colors.dart';
import 'utils/session_date_display.dart';
import 'utils/session_wayfinding.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';

/// Session selection: list available sessions (optionally filtered by pre-registration).
/// On tap: confirm modal → orchestrator.checkInToTargetSession → confirmation screen.
class SessionSelectionScreen extends StatefulWidget {
  const SessionSelectionScreen({
    super.key,
    required this.event,
    required this.eventSlug,
    required this.eventId,
    required this.registrantId,
    required this.registrantName,
    required this.source,
    this.preRegisteredSessionIds,
    this.sessionCatalog,
    this.orchestrator,
    this.isMainCheckIn = false,
  });

  final EventModel event;
  final String eventSlug;
  final String eventId;
  final String registrantId;
  final String registrantName;
  final CheckinSource source;
  /// When set, show only these sessions (filter by availability). Empty = show all available.
  final List<String>? preRegisteredSessionIds;
  final SessionCatalogService? sessionCatalog;
  final CheckinOrchestratorService? orchestrator;
  /// When true, hide app bar back button (main check-in flow).
  final bool isMainCheckIn;

  @override
  State<SessionSelectionScreen> createState() => _SessionSelectionScreenState();
}

class _SessionSelectionScreenState extends State<SessionSelectionScreen> {
  late SessionCatalogService _catalog;
  late CheckinOrchestratorService _orchestrator;
  List<SessionWithAvailability> _sessions = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _catalog = widget.sessionCatalog ?? SessionCatalogService();
    _orchestrator = widget.orchestrator ?? CheckinOrchestratorService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _catalog.listAvailableSessions(
        widget.eventId,
        filterSessionIds: widget.preRegisteredSessionIds,
      );
      if (mounted) {
        setState(() {
          _sessions = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onTapSession(SessionWithAvailability item) async {
    final session = item.session;
    // Disable when full, closed, or !session.isAvailable (capacity/status).
    final disabled = !session.isAvailable ||
        item.label == SessionAvailabilityLabel.full ||
        item.label == SessionAvailabilityLabel.closed;
    if (disabled) return;

    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Session'),
        content: Text(
          'Check in to "${session.displayName}"?\n'
          '${session.capacity > 0 ? (item.remainingSeats <= 0 ? "Session is full." : "${item.remainingSeats} seats remaining.") : "Unlimited seating."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final outcome = await _orchestrator.checkInToTargetSession(
        eventId: widget.eventId,
        registrantId: widget.registrantId,
        targetSessionId: session.id,
        source: widget.source,
      );

      if (!mounted) return;
      if (outcome.alreadyCheckedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already checked into this session.')),
        );
        await _load();
        return;
      }
      if (outcome.errorCode != null) {
        final msg = outcome.errorMessage ?? outcome.errorCode;
        if (outcome.errorCode == 'resource-exhausted' ||
            outcome.errorMessage?.toLowerCase().contains('full') == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session full. $msg')),
          );
          await _load();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $msg')),
        );
        await _load();
        return;
      }
      if (outcome.didCheckIn && outcome.session != null) {
        if (!mounted) return;
        context.pushReplacement(
          '/events/${widget.eventSlug}/checkin/confirmation',
          extra: {
            'event': widget.event,
            'eventId': widget.eventId,
            'eventSlug': widget.eventSlug,
            'session': outcome.session,
            'registrantId': widget.registrantId,
            'registrantName': widget.registrantName,
            'checkedInAt': outcome.checkedInAt,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: widget.event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 520,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isMainCheckIn,
        leading: widget.isMainCheckIn
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: NlcPalette.cream),
                onPressed: () => context.pop(),
              ),
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
                      'Select Your Session',
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
                      widget.registrantName,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        color: NlcPalette.cream,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.preRegisteredSessionIds != null &&
                              widget.preRegisteredSessionIds!.isNotEmpty
                          ? 'You are registered for these sessions.'
                          : 'Choose an available session to continue.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.35,
                        color: NlcPalette.cream.withValues(alpha: 0.85),
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 18),
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
                    else if (_sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No sessions available.',
                          style: GoogleFonts.inter(
                            color: NlcPalette.cream.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._sessions.map((item) {
                        final session = item.session;
                        final disabled = !session.isAvailable ||
                            item.label == SessionAvailabilityLabel.full ||
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
                            onTap: disabled ? null : () => _onTapSession(item),
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

}

/// Reusable wayfinding-first session card. Matches reference: colored banner with circle + "COLOR SESSION" + title; body with location, full capacity line, Available chip.
class SessionSelectionCard extends StatelessWidget {
  const SessionSelectionCard({
    super.key,
    required this.session,
    required this.remainingSeats,
    required this.label,
    required this.color,
    this.preRegisteredCount = 0,
    this.onTap,
    this.isPreview = false,
  });

  final Session session;
  final int remainingSeats;
  final SessionAvailabilityLabel label;
  final Color color;
  final int preRegisteredCount;
  final VoidCallback? onTap;
  /// When true, card is non-interactive and full opacity (e.g. preview on main check-in).
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final disabled = !isPreview && onTap == null;
    final colorName = resolveSessionColorName(resolveSessionColorHex(session));
    final textOnColor = contrastTextColorOn(color);

    // Capacity line: capacity − pre-registered − non-registered-checked-in = remaining.
    // nonRegisteredCheckedIn is derived from the pre-reg priority remainingSeats passed in.
    final nonRegCheckedIn = session.capacity > 0
        ? (session.capacity - preRegisteredCount - remainingSeats).clamp(0, session.attendanceCount)
        : session.attendanceCount;
    final capacityText = session.capacity > 0
        ? (remainingSeats <= 0
            ? 'Full · ${session.capacity} capacity · $preRegisteredCount pre-registered'
            : '${session.capacity} total · $preRegisteredCount pre-registered · $nonRegCheckedIn non-registered checked in · $remainingSeats remaining')
        : 'Unlimited seating · ${session.attendanceCount} checked in';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.78 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: isPreview
            ? IgnorePointer(
                child: _SessionSelectionCardContent(
                  session: session,
                  color: color,
                  colorName: colorName,
                  textOnColor: textOnColor,
                  capacityText: capacityText,
                  label: label,
                  disabled: false,
                ),
              )
            : InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: _SessionSelectionCardContent(
                  session: session,
                  color: color,
                  colorName: colorName,
                  textOnColor: textOnColor,
                  capacityText: capacityText,
                  label: label,
                  disabled: disabled,
                ),
              ),
      ),
    );
  }
}

class _SessionSelectionCardContent extends StatelessWidget {
  const _SessionSelectionCardContent({
    required this.session,
    required this.color,
    required this.colorName,
    required this.textOnColor,
    required this.capacityText,
    required this.label,
    required this.disabled,
  });

  final Session session;
  final Color color;
  final String colorName;
  final Color textOnColor;
  final String capacityText;
  final SessionAvailabilityLabel label;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Ink(
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.white.withValues(alpha: 0.60)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored banner: circle on left + "BLUE SESSION" + session title (left-aligned)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(color: color),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: textOnColor.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$colorName SESSION',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: textOnColor.withValues(alpha: 0.92),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                session.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: textOnColor,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body: location row + capacity line; Available chip on right
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 18,
                                    color: Colors.black.withValues(alpha: 0.70),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      session.location ?? '—',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withValues(alpha: 0.85),
                                      ),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                              if (getSessionDateDisplay(session).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  getSessionDateDisplay(session),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black.withValues(alpha: 0.72),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                capacityText,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SessionStatusChip(label: label),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

class _SessionStatusChip extends StatelessWidget {
  const _SessionStatusChip({required this.label});

  final SessionAvailabilityLabel label;

  @override
  Widget build(BuildContext context) {
    String labelStr;
    Color bg;
    Color fg;
    switch (label) {
      case SessionAvailabilityLabel.closed:
        labelStr = 'Closed';
        bg = const Color(0xFFE9EDF3);
        fg = const Color(0xFF5E6A78);
        break;
      case SessionAvailabilityLabel.full:
        labelStr = 'Full';
        bg = const Color(0xFFFBE8E8);
        fg = const Color(0xFFB84A4A);
        break;
      case SessionAvailabilityLabel.almostFull:
        labelStr = 'Almost Full';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case SessionAvailabilityLabel.available:
        labelStr = 'Available';
        bg = const Color(0xFFE3F2EA);
        fg = const Color(0xFF2E7D66);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelStr,
        style: GoogleFonts.inter(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}


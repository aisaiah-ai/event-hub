import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/nlc_sessions.dart';
import '../../../models/session.dart';
import '../../../services/checkin_orchestrator_service.dart';
import '../../../services/session_catalog_service.dart';
import '../../../services/session_registration_service.dart';
import '../../../theme/nlc_palette.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'session_selection_screen.dart';
import 'theme/checkin_theme.dart';
import 'utils/session_date_display.dart';
import 'utils/session_wayfinding.dart';
import 'widgets/conference_header.dart';
import 'widgets/footer_credits.dart';

/// Session-aware check-in gate: pre-registered (locked session) vs not registered (selection).
/// MODE A: 1 session in sessionRegistrations → locked session card + Confirm & Check In.
/// MODE B: 0 sessions → "Select Your Session" list with capacity/status chips.
/// Multiple sessions → push to SessionSelectionScreen.
class RegistrantResolvedScreen extends StatefulWidget {
  const RegistrantResolvedScreen({
    super.key,
    required this.event,
    required this.eventSlug,
    required this.eventId,
    required this.registrantId,
    required this.registrantName,
    required this.source,
    required this.isMainCheckIn,
    this.sessionRegistrationService,
    this.sessionCatalogService,
    this.orchestrator,
  });

  final EventModel event;
  final String eventSlug;
  final String eventId;
  final String registrantId;
  final String registrantName;
  final CheckinSource source;
  final bool isMainCheckIn;
  final SessionRegistrationService? sessionRegistrationService;
  final SessionCatalogService? sessionCatalogService;
  final CheckinOrchestratorService? orchestrator;

  @override
  State<RegistrantResolvedScreen> createState() =>
      _RegistrantResolvedScreenState();
}

enum _RegistrationMode { loading, one, multiple, none }

class _RegistrantResolvedScreenState extends State<RegistrantResolvedScreen> {
  _RegistrationMode _mode = _RegistrationMode.loading;
  Session? _singleSession;
  String? _singleSessionId;
  int _singleSessionPreRegCount = 0;
  int? _singleSessionRemainingSeats;
  List<SessionWithAvailability> _sessionsWithAvailability = [];
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRegistrationState();
  }

  Future<void> _loadRegistrationState() async {
    setState(() {
      _mode = _RegistrationMode.loading;
      _error = null;
    });
    final regService =
        widget.sessionRegistrationService ?? SessionRegistrationService();
    final catalog =
        widget.sessionCatalogService ?? SessionCatalogService();

    try {
      final sessionIds = await regService.getRegistrantSessionRegistration(
        widget.eventId,
        widget.registrantId,
      );

      if (!mounted) return;

      if (sessionIds.length == 1) {
        final sessionId = sessionIds.single;
        final session = await catalog.getSession(widget.eventId, sessionId);
        if (!mounted) return;
        // Show the session they registered for. If session doc is missing in Firestore, show available list instead.
        if (session != null) {
          final regService =
              widget.sessionRegistrationService ?? SessionRegistrationService();
          final preRegCounts =
              await regService.getPreRegisteredCountsPerSession(widget.eventId);
          final withAvail = await catalog.getSessionWithAvailability(widget.eventId, sessionId);
          if (!mounted) return;
          setState(() {
            _mode = _RegistrationMode.one;
            _singleSessionId = sessionId;
            _singleSession = session;
            _singleSessionPreRegCount = preRegCounts[sessionId] ?? 0;
            _singleSessionRemainingSeats = withAvail?.remainingSeats;
          });
          return;
        }
        // Pre-registered session not found in Firestore (e.g. dialogue doc not created); fall back to available sessions.
        await _refreshSessionList();
        return;
      }

      if (sessionIds.length > 1) {
        setState(() => _mode = _RegistrationMode.multiple);
        if (!mounted) return;
        context.pushReplacement(
          '/events/${widget.eventSlug}/checkin/session-selection',
          extra: {
            'event': widget.event,
            'eventId': widget.eventId,
            'eventSlug': widget.eventSlug,
            'registrantId': widget.registrantId,
            'registrantName': widget.registrantName,
            'source': widget.source,
            'preRegisteredSessionIds': sessionIds,
            'isMainCheckIn': widget.isMainCheckIn,
          },
        );
        return;
      }

      await _refreshSessionList();
    } catch (e, st) {
      debugPrint('[RegistrantResolved] loadRegistrationState failed: $e');
      debugPrint('[RegistrantResolved] stack: $st');
      if (mounted) {
        setState(() {
          _mode = _RegistrationMode.none;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _refreshSessionList() async {
    final catalog =
        widget.sessionCatalogService ?? SessionCatalogService();
    var list = await catalog.listSessionsWithAvailability(widget.eventId);
    // For non-registered: show only breakout sessions. Main Check-In is not selectable here
    // (orchestrator ensures main check-in automatically when they check in to a breakout).
    final mainId = NlcSessions.mainCheckInSessionId;
    list = list.where((e) => e.session.id != mainId).toList();
    if (!mounted) return;
    setState(() {
      _mode = _RegistrationMode.none;
      _sessionsWithAvailability = list;
      _error = null;
    });
  }

  Future<void> _onConfirmPreRegistered() async {
    if (_singleSessionId == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionLoading = true);
    final orchestrator =
        widget.orchestrator ?? CheckinOrchestratorService();
    try {
      final outcome = await orchestrator.checkInToTargetSession(
        eventId: widget.eventId,
        registrantId: widget.registrantId,
        targetSessionId: _singleSessionId!,
        source: widget.source,
      );
      if (!mounted) return;
      setState(() => _actionLoading = false);
      if (outcome.didCheckIn && outcome.session != null) {
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
      } else if (outcome.alreadyCheckedIn) {
        final session = outcome.session ?? _singleSession;
        if (session != null) {
          context.pushReplacement(
            '/events/${widget.eventSlug}/checkin/confirmation',
            extra: {
              'event': widget.event,
              'eventId': widget.eventId,
              'eventSlug': widget.eventSlug,
              'session': session,
              'registrantId': widget.registrantId,
              'registrantName': widget.registrantName,
              'checkedInAt': outcome.checkedInAt,
            },
          );
        } else {
          setState(() => _error = 'Already checked in (session details unavailable).');
        }
      } else {
        setState(() => _error = outcome.errorMessage ?? outcome.errorCode ?? 'Check-in failed.');
      }
    } catch (e) {
      debugPrint('[RegistrantResolved] checkIn failed: $e');
      if (e is FirebaseException) {
        debugPrint('[RegistrantResolved] code=${e.code} message=${e.message}');
      }
      if (mounted) {
        setState(() {
          _actionLoading = false;
          _error = e is FirebaseException ? (e.message ?? e.code) : e.toString();
        });
      }
    }
  }

  Future<void> _onSessionSelected(SessionWithAvailability item) async {
    final session = item.session;
    final disabled = item.label == SessionAvailabilityLabel.full ||
        item.label == SessionAvailabilityLabel.closed;
    if (disabled) return;

    HapticFeedback.mediumImpact();
    final dateTime = getSessionDateDisplay(session);
    final remainingStr = session.capacity > 0
        ? 'Remaining Seats: ${item.remainingSeats}'
        : 'No capacity limit';
    final location = session.location ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Session Selection?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (dateTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(dateTime),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(location),
            ],
            const SizedBox(height: 8),
            Text(remainingStr),
          ],
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

    setState(() => _actionLoading = true);
    final orchestrator =
        widget.orchestrator ?? CheckinOrchestratorService();
    try {
      final outcome = await orchestrator.checkInToTargetSession(
        eventId: widget.eventId,
        registrantId: widget.registrantId,
        targetSessionId: session.id,
        source: widget.source,
      );
      if (!mounted) return;
      setState(() => _actionLoading = false);
      if (outcome.errorCode == 'resource-exhausted' ||
          (outcome.errorMessage ?? '').toLowerCase().contains('full')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This session just became full.')),
        );
        await _refreshSessionList();
        return;
      }
      if (outcome.didCheckIn && outcome.session != null) {
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
      } else if (outcome.alreadyCheckedIn) {
        final confirmSession = outcome.session ?? session;
        context.pushReplacement(
          '/events/${widget.eventSlug}/checkin/confirmation',
          extra: {
            'event': widget.event,
            'eventId': widget.eventId,
            'eventSlug': widget.eventSlug,
            'session': confirmSession,
            'registrantId': widget.registrantId,
            'registrantName': widget.registrantName,
            'checkedInAt': outcome.checkedInAt,
          },
        );
      } else {
        setState(() => _error = outcome.errorMessage ?? outcome.errorCode ?? 'Check-in failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        if (e is FirebaseException &&
            (e.code == 'resource-exhausted' ||
                (e.message ?? '').toLowerCase().contains('full'))) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This session just became full.')),
          );
          _refreshSessionList();
        } else {
          setState(() => _error = e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: widget.event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 600,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.afterHeader),
                  ConferenceHeader(logoUrl: widget.event.logoUrl),
                  const SizedBox(height: AppSpacing.betweenSections),
                  if (_mode == _RegistrationMode.loading) ...[
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(color: NlcPalette.cream),
                      ),
                    ),
                  ] else if (_mode == _RegistrationMode.one) ...[
                    _buildHeader('Main Check-In', widget.registrantName, 'Ready to check in'),
                    if (_singleSession != null) ...[
                      const SizedBox(height: 24),
                      _PreRegisteredSessionCard(
                        session: _singleSession!,
                        color: sessionColorFromHex(_singleSession!.colorHex),
                        preRegisteredCount: _singleSessionPreRegCount,
                        remainingSeats: _singleSessionRemainingSeats,
                      ),
                    ] else if (_singleSessionId != null) ...[
                      const SizedBox(height: 24),
                      _PlaceholderSessionCard(sessionId: _singleSessionId!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.orange.shade200, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _actionLoading ? null : _onConfirmPreRegistered,
                        style: FilledButton.styleFrom(
                          backgroundColor: NlcPalette.brandBlue,
                          foregroundColor: NlcPalette.cream,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _actionLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NlcPalette.cream,
                                ),
                              )
                            : const Text('Confirm & Check In'),
                      ),
                    ),
                  ] else if (_mode == _RegistrationMode.none) ...[
                    _buildSessionSelectionHeader(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.orange.shade200, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_sessionsWithAvailability.isEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'No sessions available.',
                        style: GoogleFonts.inter(
                          color: NlcPalette.cream.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      if (_actionLoading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: NlcPalette.cream),
                          ),
                        )
                      else
                        ..._sessionsWithAvailability.map((item) {
                          final disabled = item.label == SessionAvailabilityLabel.full ||
                              item.label == SessionAvailabilityLabel.closed;
                          final color = sessionColorFromHex(item.session.colorHex);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: SessionSelectionCard(
                              session: item.session,
                              remainingSeats: item.remainingSeats,
                              preRegisteredCount: item.preRegisteredCount,
                              label: item.label,
                              color: color,
                              onTap: disabled ? null : () => _onSessionSelected(item),
                            ),
                          );
                        }),
                    ],
                  ],
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

  /// Left-aligned header matching SessionSelectionScreen: "Select Your Session", name, subtitle.
  Widget _buildSessionSelectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          'Choose an available session to continue.',
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.35,
            color: NlcPalette.cream.withValues(alpha: 0.85),
          ),
          textAlign: TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildHeader(String title, String name, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: NlcPalette.cream.withValues(alpha: 0.95),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.playfairDisplay(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: NlcPalette.cream,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: NlcPalette.cream.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PreRegisteredSessionCard extends StatelessWidget {
  const _PreRegisteredSessionCard({
    required this.session,
    required this.color,
    this.preRegisteredCount = 0,
    this.remainingSeats,
  });

  final Session session;
  final Color color;
  final int preRegisteredCount;
  final int? remainingSeats;

  @override
  Widget build(BuildContext context) {
    final dateTime = getSessionDateDisplay(session);
    final total = session.capacity;
    final checkedIn = session.attendanceCount;
    // Pre-reg priority remaining: capacity − preRegistered − nonRegisteredCheckedIn.
    final remaining = remainingSeats ?? session.remainingSeats;
    // Derive non-registered checked-in from the pre-reg priority formula.
    final nonRegCheckedIn = total > 0
        ? (total - preRegisteredCount - remaining).clamp(0, checkedIn)
        : checkedIn;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large colored header (wayfinding identity)
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: color),
            child: Center(
              child: Text(
                session.displayName,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Accent line
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NlcPalette.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'PRE-REGISTERED',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NlcPalette.success,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are pre-registered for this session.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: NlcPalette.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (dateTime.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: color),
                      const SizedBox(width: 8),
                      Text(
                        dateTime,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary87),
                      ),
                    ],
                  ),
                ],
                if (session.location != null && session.location!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.location!,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary87),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (total > 0) ...[
                  Text(
                    remaining <= 0
                        ? 'Full · $total capacity · $preRegisteredCount pre-registered'
                        : '$total total · $preRegisteredCount pre-registered · $nonRegCheckedIn non-registered checked in · $remaining remaining',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary87.withValues(alpha: 0.9),
                    ),
                  ),
                ] else
                  Text(
                    'Unlimited seating · $checkedIn checked in',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary87.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderSessionCard extends StatelessWidget {
  const _PlaceholderSessionCard({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NlcPalette.brandBlue.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 48,
            decoration: BoxDecoration(
              color: NlcPalette.brandBlue,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              sessionId,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: NlcPalette.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'PRE-REGISTERED',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NlcPalette.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

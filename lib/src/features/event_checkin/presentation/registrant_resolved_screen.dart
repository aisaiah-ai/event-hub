import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/session.dart';
import '../../../services/checkin_orchestrator_service.dart';
import '../../../services/session_catalog_service.dart';
import '../../../services/session_registration_service.dart';
import '../../../theme/nlc_palette.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
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
        setState(() {
          _mode = _RegistrationMode.one;
          _singleSessionId = sessionId;
          _singleSession = session;
        });
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
    final list = await catalog.listSessionsWithAvailability(widget.eventId);
    if (!mounted) return;
    setState(() {
      _mode = _RegistrationMode.none;
      _sessionsWithAvailability = list;
      _error = null;
    });
  }

  Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return NlcPalette.brandBlue;
    final h = hex.startsWith('#') ? hex : '#$hex';
    if (h.length == 7) {
      final r = int.tryParse(h.substring(1, 3), radix: 16);
      final g = int.tryParse(h.substring(3, 5), radix: 16);
      final b = int.tryParse(h.substring(5, 7), radix: 16);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    }
    return NlcPalette.brandBlue;
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
    String dateTime = '';
    if (session.startAt != null) {
      dateTime = DateFormat.MMMd().add_jm().format(session.startAt!);
      if (session.endAt != null) {
        dateTime += ' – ${DateFormat.jm().format(session.endAt!)}';
      }
    }
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

  /// Chip label for MODE B: 10% threshold for Almost Full.
  String _sessionChipLabel(SessionWithAvailability item) {
    if (item.label == SessionAvailabilityLabel.closed) return 'CLOSED';
    if (item.label == SessionAvailabilityLabel.full) return 'FULL';
    final s = item.session;
    if (s.capacity > 0 && item.remainingSeats <= (s.capacity * 0.1)) {
      return 'Almost Full';
    }
    return 'Available';
  }

  Color _sessionChipColor(SessionWithAvailability item) {
    if (item.label == SessionAvailabilityLabel.closed) return AppColors.textPrimary87;
    if (item.label == SessionAvailabilityLabel.full) return Colors.red;
    final s = item.session;
    if (s.capacity > 0 && item.remainingSeats <= (s.capacity * 0.1)) {
      return Colors.orange;
    }
    return NlcPalette.success;
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
        leading: IconButton(
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
                        color: _colorFromHex(_singleSession!.colorHex),
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
                    _buildHeader('Select Your Session', widget.registrantName, 'Choose an available session to continue.'),
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
                      const SizedBox(height: 24),
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
                          final color = _colorFromHex(item.session.colorHex);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _SelectableSessionCard(
                              session: item.session,
                              remainingSeats: item.remainingSeats,
                              chipLabel: _sessionChipLabel(item),
                              chipColor: _sessionChipColor(item),
                              color: color,
                              disabled: disabled,
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
  });

  final Session session;
  final Color color;

  @override
  Widget build(BuildContext context) {
    String dateTime = '';
    if (session.startAt != null) {
      dateTime = DateFormat.MMMd().add_jm().format(session.startAt!);
      if (session.endAt != null) {
        dateTime += ' – ${DateFormat.jm().format(session.endAt!)}';
      }
    }
    final capacityLine = session.capacity > 0
        ? (session.attendanceCount >= session.capacity
            ? 'Session Full'
            : 'Remaining Seats: ${session.remainingSeats}')
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  session.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
          if (dateTime.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: AppColors.textPrimary87),
                const SizedBox(width: 8),
                Text(
                  dateTime,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary87),
                ),
              ],
            ),
          ],
          if (session.location != null && session.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: AppColors.textPrimary87),
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
          if (capacityLine != null) ...[
            const SizedBox(height: 8),
            Text(
              capacityLine,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary87.withValues(alpha: 0.9),
              ),
            ),
          ],
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

class _SelectableSessionCard extends StatelessWidget {
  const _SelectableSessionCard({
    required this.session,
    required this.remainingSeats,
    required this.chipLabel,
    required this.chipColor,
    required this.color,
    required this.disabled,
    this.onTap,
  });

  final Session session;
  final int remainingSeats;
  final String chipLabel;
  final Color chipColor;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String dateTime = '';
    if (session.startAt != null) {
      dateTime = DateFormat.MMMd().add_jm().format(session.startAt!);
      if (session.endAt != null) {
        dateTime += ' – ${DateFormat.jm().format(session.endAt!)}';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: disabled ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        session.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        chipLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (dateTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: AppColors.textPrimary87),
                      const SizedBox(width: 8),
                      Text(
                        dateTime,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary87),
                      ),
                    ],
                  ),
                ],
                if (session.location != null && session.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: AppColors.textPrimary87),
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
                if (session.capacity > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Remaining seats: $remainingSeats',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary87.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

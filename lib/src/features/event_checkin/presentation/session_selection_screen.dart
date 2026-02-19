import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/session.dart';
import '../../../services/checkin_orchestrator_service.dart';
import '../../../services/session_catalog_service.dart';
import '../../../theme/nlc_palette.dart';
import '../../events/data/event_model.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
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
        title: const Text('Confirm Check-In'),
        content: Text(
          'Check into ${session.displayName}?\n'
          'Remaining seats: ${item.remainingSeats == 0x7FFFFFFF ? "No limit" : item.remainingSeats}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Check In'),
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
        leading: IconButton(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.afterHeader),
                    ConferenceHeader(logoUrl: widget.event.logoUrl),
                    const SizedBox(height: AppSpacing.betweenSections),
                    Text(
                      widget.preRegisteredSessionIds != null &&
                              widget.preRegisteredSessionIds!.isNotEmpty
                          ? 'You are registered for these sessions'
                          : 'Choose a session',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: NlcPalette.cream,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.belowSubtitle),
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
                        final color = sessionColorFromHex(session.colorHex);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.betweenSecondaryCards),
                          child: _SessionCard(
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.remainingSeats,
    this.preRegisteredCount = 0,
    required this.label,
    required this.color,
    this.onTap,
  });

  final Session session;
  final int remainingSeats;
  final int preRegisteredCount;
  final SessionAvailabilityLabel label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final labelStr = SessionCatalogService.availabilityLabelString(label);
    final chipColor = _chipColor(label);
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
                Container(height: 4, color: color),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              labelStr,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: chipColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (session.location != null && session.location!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppColors.textPrimary87),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                session.location!,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (dateTime.isNotEmpty) ...[
                        if (session.location != null && session.location!.isNotEmpty) const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: AppColors.textPrimary87),
                            const SizedBox(width: 8),
                            Text(
                              dateTime,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textPrimary87,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        session.capacity > 0
                            ? '${session.capacity} total · $preRegisteredCount pre-registered · ${session.attendanceCount} checked in · ${remainingSeats <= 0 ? "Full" : "$remainingSeats remaining"}'
                            : 'No capacity limit · $preRegisteredCount pre-registered · ${session.attendanceCount} checked in',
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
          ),
        ),
      ),
    );
  }

  Color _chipColor(SessionAvailabilityLabel label) {
    switch (label) {
      case SessionAvailabilityLabel.available:
        return NlcPalette.success;
      case SessionAvailabilityLabel.almostFull:
        return Colors.orange;
      case SessionAvailabilityLabel.full:
        return Colors.red;
      case SessionAvailabilityLabel.closed:
        return AppColors.textPrimary87;
    }
  }
}


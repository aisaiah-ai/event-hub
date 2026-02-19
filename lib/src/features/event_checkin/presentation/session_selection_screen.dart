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
          '${session.capacity > 0 ? (item.remainingSeats <= 0 ? "Session is full." : "${item.remainingSeats} seats remaining.") : "Open capacity."}',
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
                          padding: const EdgeInsets.only(bottom: 24),
                          child: SessionSelectionCard(
                            session: session,
                            remainingSeats: item.remainingSeats,
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

/// Reusable wayfinding-first session card. Color = room identity only; capacity copy simplified.
class SessionSelectionCard extends StatefulWidget {
  const SessionSelectionCard({
    super.key,
    required this.session,
    required this.remainingSeats,
    required this.label,
    required this.color,
    this.onTap,
  });

  final Session session;
  final int remainingSeats;
  final SessionAvailabilityLabel label;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<SessionSelectionCard> createState() => _SessionSelectionCardState();
}

class _SessionSelectionCardState extends State<SessionSelectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final disabled = widget.onTap == null;
    final labelStr = SessionCatalogService.availabilityLabelString(widget.label);
    final chipColor = _chipColor(widget.label);
    final colorName = resolveSessionColorName(session.colorHex);
    final textOnColor = contrastTextColorOn(widget.color);

    final capacityText = session.capacity > 0
        ? (widget.remainingSeats <= 0 ? 'Full' : '${widget.remainingSeats} seats remaining')
        : 'Open capacity';

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: disabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: widget.onTap != null
                  ? Border.all(
                      color: widget.color.withValues(alpha: _pressed ? 0.8 : 0.4),
                      width: _pressed ? 2.5 : 2,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: _pressed ? 20 : 16,
                  offset: Offset(0, _pressed ? 6 : 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Colored header – 48px min, wayfinding identity
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: widget.color),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$colorName SESSION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                          color: textOnColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textOnColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // White body – 24px padding, 16px spacing
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location row with chip aligned right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 18, color: AppColors.textPrimary87),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.location ?? '—',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 16),
                      Text(
                        capacityText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textPrimary87.withValues(alpha: 0.95),
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


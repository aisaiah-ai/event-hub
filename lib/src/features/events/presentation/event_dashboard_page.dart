import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../widgets/event_page_scaffold.dart';
import '../widgets/live_schedule_panel.dart';
import '../widgets/live_checkin_panel.dart';
import '../widgets/live_photos_panel.dart';

/// Event Command Center — side-by-side live schedule + check-in dashboard.
///
/// Route: /events/:eventSlug/dashboard
///
/// Responsive layout:
/// - Desktop/projector (>900px): side-by-side panels
/// - Mobile (<900px): stacked vertically
///
/// All data streams from Firestore in real-time.
class EventDashboardPage extends StatefulWidget {
  const EventDashboardPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<EventDashboardPage> createState() => _EventDashboardPageState();
}

class _EventDashboardPageState extends State<EventDashboardPage> {
  final _repo = EventRepository();
  EventModel? _event;
  bool _loading = true;
  String? _error;

  /// Debug time override — only available in debug mode.
  DateTime? _debugNow;

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
      final event = await _repo.getEventBySlug(widget.eventSlug);
      if (event == null) throw StateError('Event not found');
      setState(() {
        _event = event;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: _event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 1400,
      overlayOpacity: 0.82,
      overlayTint: const Color(0xFF0A0A14),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4A340)),
            )
          : _error != null
              ? _buildError()
              : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF4A340), size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: GoogleFonts.inter(
              color: const Color(0xFF8888A0),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Color(0xFFF4A340)),
            label: Text(
              'Retry',
              style: GoogleFonts.inter(color: const Color(0xFFF4A340)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final event = _event!;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final isKiosk = constraints.maxWidth > 1200;

          return Column(
            children: [
              // ── Compact header ──
              _DashboardHeader(event: event, isKiosk: isKiosk),

              // ── Debug time simulator (debug mode only) ──
              if (kDebugMode)
                _TimeSimulator(
                  event: event,
                  debugNow: _debugNow,
                  onTimeChanged: (t) => setState(() => _debugNow = t),
                ),

              SizedBox(height: isKiosk ? 16 : 12),

              // ── Side-by-side panels ──
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isKiosk ? 20 : 14,
                  ),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: LiveSchedulePanel(
                                event: event,
                                isKiosk: isKiosk,
                                debugNow: _debugNow,
                              ),
                            ),
                            SizedBox(width: isKiosk ? 16 : 12),
                            Expanded(
                              flex: 4,
                              child: LiveCheckinPanel(
                                event: event,
                                isKiosk: isKiosk,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: LiveSchedulePanel(
                                event: event,
                                isKiosk: isKiosk,
                                debugNow: _debugNow,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: LiveCheckinPanel(
                                event: event,
                                isKiosk: isKiosk,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: isKiosk ? 12 : 8),

              // ── Live Photos strip ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isKiosk ? 20 : 14,
                ),
                child: LivePhotosPanel(
                  event: event,
                  isKiosk: isKiosk,
                  maxHeight: isKiosk ? 260 : 200,
                ),
              ),

              // ── Footer ──
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isKiosk ? 12 : 8,
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8888A0).withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    children: [
                      const TextSpan(text: 'Events powered by '),
                      TextSpan(
                        text: 'Aisaiah',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF4A340).withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Debug Time Simulator ────────────────────────────────────────────────────

class _TimeSimulator extends StatelessWidget {
  const _TimeSimulator({
    required this.event,
    required this.debugNow,
    required this.onTimeChanged,
  });

  final EventModel event;
  final DateTime? debugNow;
  final ValueChanged<DateTime?> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    // Event day times for quick jumping
    final eventDay = event.startDate;
    final presets = <_TimePreset>[
      // Use UTC to match fallback session times (DateTime.utc in event_repository)
      _TimePreset('REAL', null),
      _TimePreset('5:00 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 17, 0)),
      _TimePreset('5:30 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 17, 30)),
      _TimePreset('5:50 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 17, 50)),
      _TimePreset('6:00 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 18, 0)),
      _TimePreset('6:30 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 18, 30)),
      _TimePreset('7:00 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 19, 0)),
      _TimePreset('7:30 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 19, 30)),
      _TimePreset('8:00 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 20, 0)),
      _TimePreset('8:30 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 20, 30)),
      _TimePreset('9:00 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 21, 0)),
      _TimePreset('9:30 PM', DateTime.utc(eventDay.year, eventDay.month, eventDay.day, 21, 30)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6D4CFF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bug_report, color: const Color(0xFF6D4CFF), size: 16),
          const SizedBox(width: 8),
          Text(
            debugNow != null
                ? 'SIM: ${DateFormat.jm().format(debugNow!)}'
                : 'TIME SIM',
            style: GoogleFonts.inter(
              color: debugNow != null
                  ? const Color(0xFF6D4CFF)
                  : const Color(0xFF8888A0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((p) {
                  final isSelected = (p.time == null && debugNow == null) ||
                      (p.time != null && debugNow != null &&
                          p.time!.isAtSameMomentAs(debugNow!));
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () => onTimeChanged(p.time),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6D4CFF).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6D4CFF)
                                : const Color(0xFF3A3A4A),
                          ),
                        ),
                        child: Text(
                          p.label,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? const Color(0xFF6D4CFF)
                                : const Color(0xFF8888A0),
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePreset {
  const _TimePreset(this.label, this.time);
  final String label;
  final DateTime? time;
}

// ─── Dashboard Header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.event, this.isKiosk = false});

  final EventModel event;
  final bool isKiosk;

  @override
  Widget build(BuildContext context) {
    final k = isKiosk;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: k ? 20 : 14),
      padding: EdgeInsets.symmetric(
        horizontal: k ? 24 : 18,
        vertical: k ? 18 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Row(
        children: [
          // Logo
          if (event.effectiveLogoUrl != null)
            Padding(
              padding: EdgeInsets.only(right: k ? 18 : 14),
              child: EventLogo(
                logoUrl: event.effectiveLogoUrl,
                size: k ? 64 : 48,
              ),
            ),

          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.organizationName != null)
                  Text(
                    event.organizationName!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF4A340),
                      fontSize: k ? 11 : 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                Text(
                  event.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: k ? 22 : 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: k ? 14 : 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('MMMM d').format(event.startDate),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: k ? 14 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '\u00B7',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.location_on_outlined,
                      size: k ? 14 : 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        event.locationName,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: k ? 14 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // LIVE badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: k ? 16 : 12,
              vertical: k ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF7AE3A5).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7AE3A5).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: k ? 10 : 8,
                  height: k ? 10 : 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7AE3A5),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: k ? 8 : 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7AE3A5),
                    fontSize: k ? 14 : 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
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

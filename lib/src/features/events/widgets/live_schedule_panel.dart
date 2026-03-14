import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/firestore_config.dart';
import '../data/event_model.dart';
import '../data/event_schedule_model.dart';
import '../data/event_repository.dart';

/// Optional color overrides for theming (light/dark).
class SchedulePanelColors {
  const SchedulePanelColors({
    this.cardBg = const Color(0xFF1A1A2A),
    this.cardBorder = const Color(0xFF2A2A3A),
    this.primary = const Color(0xFF0E3A5D),
    this.liveGreen = const Color(0xFF7AE3A5),
    this.textPrimary = Colors.white,
    this.textMuted = const Color(0xFF8888A0),
    this.gold = const Color(0xFFF4A340),
  });

  final Color cardBg;
  final Color cardBorder;
  final Color primary;
  final Color liveGreen;
  final Color textPrimary;
  final Color textMuted;
  final Color gold;

  static const dark = SchedulePanelColors();
  static const light = SchedulePanelColors(
    cardBg: Colors.white,
    cardBorder: Color(0xFFE0E0D8),
    primary: Color(0xFF0E3A5D),
    liveGreen: Color(0xFF2B9E7A),
    textPrimary: Color(0xFF1A1A1A),
    textMuted: Color(0xFF888880),
    gold: Color(0xFFD48A20),
  );
}

/// Live schedule panel that streams sessions from Firestore,
/// highlights the current session, shows next session, and auto-scrolls.
/// Designed for kiosk / projector display.
class LiveSchedulePanel extends StatefulWidget {
  const LiveSchedulePanel({
    super.key,
    required this.event,
    this.isKiosk = false,
    this.debugNow,
    this.colors = SchedulePanelColors.dark,
  });

  final EventModel event;
  final bool isKiosk;
  final DateTime? debugNow;
  final SchedulePanelColors colors;

  @override
  State<LiveSchedulePanel> createState() => _LiveSchedulePanelState();
}

class _LiveSchedulePanelState extends State<LiveSchedulePanel> {
  StreamSubscription? _sessionsSub;
  Timer? _ticker;
  Timer? _autoScrollTimer;
  List<EventSession> _sessions = [];
  bool _loading = true;
  DateTime _lastUpdated = DateTime.now();
  final _scrollController = ScrollController();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _startStream();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
        if (!_hovered) _autoScrollToCurrent();
      }
    });
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_hovered && mounted) _slowScroll();
    });
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _ticker?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startStream() {
    final fs = FirestoreConfig.instanceOrNull;
    if (fs == null) {
      _loadFallback();
      return;
    }

    final docId = widget.event.id == 'march-cluster-2026'
        ? 'march-assembly'
        : widget.event.id;

    // ignore: avoid_print
    print('[LiveSchedule] event.id=${widget.event.id} docId=$docId');

    _sessionsSub = fs
        .collection('events')
        .doc(docId)
        .collection('sessions')
        .orderBy('order')
        .snapshots()
        .listen(
          (snap) {
            // ignore: avoid_print
            print('[LiveSchedule] Firestore returned ${snap.docs.length} docs');
            final sessions = snap.docs
                .map((d) {
                  // ignore: avoid_print
                  print(
                    '[LiveSchedule] doc ${d.id}: ${d.data().keys.toList()}',
                  );
                  return EventSession.fromFirestore(d.id, d.data());
                })
                .where((s) => s.id != 'main' && s.id != 'main-checkin')
                .toList();
            // ignore: avoid_print
            print('[LiveSchedule] After filter: ${sessions.length} sessions');
            if (sessions.isEmpty) {
              // ignore: avoid_print
              print(
                '[LiveSchedule] No sessions from Firestore → loading fallback',
              );
              _loadFallback();
              return;
            }
            _enrichAndSet(sessions);
          },
          onError: (e) {
            // ignore: avoid_print
            print('[LiveSchedule] Stream error: $e');
            _loadFallback();
          },
        );
  }

  Future<void> _loadFallback() async {
    // ignore: avoid_print
    print(
      '[LiveSchedule] _loadFallback called for event.id=${widget.event.id} slug=${widget.event.slug}',
    );
    try {
      final repo = EventRepository();
      final sessions = await repo.getSessions(
        widget.event.id,
        slug: widget.event.slug,
      );
      // ignore: avoid_print
      print(
        '[LiveSchedule] fallback repo returned ${sessions.length} sessions',
      );
      if (mounted) {
        setState(() {
          _sessions = sessions
              .where((s) => s.id != 'main' && s.id != 'main-checkin')
              .toList();
          _loading = false;
          _lastUpdated = DateTime.now();
        });
        // ignore: avoid_print
        print(
          '[LiveSchedule] After filter: ${_sessions.length} sessions displayed',
        );
        _autoScrollToCurrent();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[LiveSchedule] _loadFallback error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enrichAndSet(List<EventSession> sessions) async {
    try {
      final repo = EventRepository();
      final speakers = await repo.getSpeakers(
        widget.event.id,
        slug: widget.event.slug,
      );
      if (speakers.isNotEmpty) {
        final bySessionId = <String, EventSpeaker>{};
        final byName = <String, EventSpeaker>{};
        for (final sp in speakers) {
          if (sp.sessionId != null) bySessionId[sp.sessionId!] = sp;
          if (sp.displayName != null) {
            byName[sp.displayName!.toLowerCase()] = sp;
          }
          byName[sp.name.toLowerCase()] = sp;
        }

        for (var i = 0; i < sessions.length; i++) {
          final s = sessions[i];
          EventSpeaker? match = bySessionId[s.id];
          if (match == null && s.speaker != null) {
            match = byName[s.speaker!.name.toLowerCase()];
          }
          if (match != null) {
            sessions[i] = s.withSpeaker(SessionSpeaker.fromEventSpeaker(match));
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[LiveSchedule] Speaker enrichment error: $e');
    }

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
      _autoScrollToCurrent();
    }
  }

  DateTime get _now => widget.debugNow ?? DateTime.now();

  int _findActiveIndex() {
    final now = _now;
    for (var i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      if (s.startAt != null &&
          s.endAt != null &&
          now.isAfter(s.startAt!) &&
          now.isBefore(s.endAt!)) {
        return i;
      }
    }
    return -1;
  }

  int _findNextIndex() {
    final now = _now;
    for (var i = 0; i < _sessions.length; i++) {
      if (_sessions[i].startAt != null && _sessions[i].startAt!.isAfter(now)) {
        return i;
      }
    }
    return -1;
  }

  void _autoScrollToCurrent() {
    if (_sessions.isEmpty || !_scrollController.hasClients) return;
    var targetIndex = _findActiveIndex();
    if (targetIndex < 0) targetIndex = _findNextIndex();
    if (targetIndex < 0) return;

    final itemHeight = widget.isKiosk ? 130.0 : 94.0;
    final offset = (targetIndex * itemHeight).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _slowScroll() {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    if (current >= max) {
      _autoScrollToCurrent();
    } else {
      final target = (current + 80).clamp(0.0, max);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  String _updatedLabel() {
    final diff = DateTime.now().difference(_lastUpdated);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    return 'Updated ${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.isKiosk;
    final c = widget.colors;
    final activeIndex = _findActiveIndex();
    final nextIndex = _findNextIndex();

    return MouseRegion(
      onEnter: (_) => _hovered = true,
      onExit: (_) => _hovered = false,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                k ? 24.0 : 18.0,
                k ? 20.0 : 16.0,
                k ? 24.0 : 18.0,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: c.primary,
                        size: k ? 26 : 20,
                      ),
                      SizedBox(width: k ? 10 : 8),
                      Text(
                        'Live Schedule',
                        style: GoogleFonts.inter(
                          color: c.textPrimary,
                          fontSize: k ? 24 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _PulsingLiveBadge(isKiosk: k, color: c.liveGreen),
                    ],
                  ),
                  SizedBox(height: k ? 6 : 4),
                  Text(
                    _updatedLabel(),
                    style: GoogleFonts.inter(
                      color: c.liveGreen.withValues(alpha: 0.7),
                      fontSize: k ? 13 : 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: k ? 10 : 8),
                ],
              ),
            ),
            Divider(color: c.cardBorder, height: 1),

            // ── Sessions list ──
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.liveGreen))
                  : _sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet',
                        style: GoogleFonts.inter(
                          color: c.textMuted,
                          fontSize: k ? 16 : 14,
                        ),
                      ),
                    )
                  : _buildSessionList(k, activeIndex, nextIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionList(bool k, int activeIndex, int nextIndex) {
    final now = _now;
    final c = widget.colors;

    final upcoming = <int>[];
    final past = <int>[];
    for (var i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      final isPast = s.endAt != null && s.endAt!.isBefore(now);
      if (isPast) {
        past.add(i);
      } else {
        upcoming.add(i);
      }
    }

    final items = <Widget>[];

    for (final idx in upcoming) {
      final isActive = idx == activeIndex;
      items.add(
        _ScheduleItemCard(
          session: _sessions[idx],
          isKiosk: k,
          isActive: isActive,
          debugNow: widget.debugNow,
          colors: c,
        ),
      );
      if (isActive && nextIndex >= 0) {
        items.add(
          _NextSessionCard(
            session: _sessions[nextIndex],
            isKiosk: k,
            debugNow: widget.debugNow,
            colors: c,
          ),
        );
      }
    }

    if (past.isNotEmpty) {
      items.add(
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: k ? 20 : 14,
            vertical: k ? 12 : 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Divider(color: c.textMuted.withValues(alpha: 0.2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'COMPLETED',
                  style: GoogleFonts.inter(
                    color: c.textMuted.withValues(alpha: 0.4),
                    fontSize: k ? 11 : 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: c.textMuted.withValues(alpha: 0.2)),
              ),
            ],
          ),
        ),
      );

      for (final idx in past) {
        items.add(
          _ScheduleItemCard(
            session: _sessions[idx],
            isKiosk: k,
            isActive: false,
            debugNow: widget.debugNow,
            colors: c,
          ),
        );
      }
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: k ? 12 : 6),
      children: items,
    );
  }
}

// ─── Pulsing Live Badge ──────────────────────────────────────────────────────

class _PulsingLiveBadge extends StatefulWidget {
  const _PulsingLiveBadge({
    this.isKiosk = false,
    this.color = const Color(0xFF7AE3A5),
  });
  final bool isKiosk;
  final Color color;

  @override
  State<_PulsingLiveBadge> createState() => _PulsingLiveBadgeState();
}

class _PulsingLiveBadgeState extends State<_PulsingLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.isKiosk;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: k ? 14 : 10,
        vertical: k ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Container(
                width: k ? 9 : 7,
                height: k ? 9 : 7,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: 0.4 + 0.6 * _ctrl.value,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3 * _ctrl.value),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: k ? 7 : 5),
          Text(
            'LIVE',
            style: GoogleFonts.inter(
              color: widget.color,
              fontSize: k ? 13 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Schedule Item Card ──────────────────────────────────────────────────────

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({
    required this.session,
    this.isKiosk = false,
    this.isActive = false,
    this.debugNow,
    this.colors = SchedulePanelColors.dark,
  });

  final EventSession session;
  final bool isKiosk;
  final bool isActive;
  final DateTime? debugNow;
  final SchedulePanelColors colors;

  bool get _isPast {
    final now = debugNow ?? DateTime.now();
    return session.endAt != null && session.endAt!.isBefore(now);
  }

  @override
  Widget build(BuildContext context) {
    final past = _isPast;
    final k = isKiosk;
    final c = colors;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: k ? 16 : 12,
        vertical: k ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? c.liveGreen.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: c.liveGreen.withValues(alpha: 0.35))
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: c.liveGreen.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar for active session
            if (isActive)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: c.liveGreen,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isActive ? (k ? 14.0 : 10.0) : (k ? 18.0 : 14.0),
                  k ? 16.0 : 12.0,
                  k ? 18.0 : 14.0,
                  k ? 16.0 : 12.0,
                ),
                child: Opacity(
                  opacity: past ? 0.35 : 1.0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      SizedBox(
                        width: k ? 96 : 74,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.startAt != null
                                  ? DateFormat.jm().format(session.startAt!)
                                  : '',
                              style: GoogleFonts.inter(
                                color: isActive
                                    ? c.liveGreen
                                    : c.textPrimary.withValues(alpha: 0.7),
                                fontSize: k ? 22 : 16,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: k ? 10 : 8,
                                  vertical: k ? 4 : 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.liveGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: c.liveGreen.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'LIVE NOW',
                                  style: GoogleFonts.inter(
                                    color: c.liveGreen,
                                    fontSize: k ? 11 : 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Accent dot
                      Padding(
                        padding: EdgeInsets.only(
                          top: k ? 6 : 4,
                          right: k ? 14 : 10,
                        ),
                        child: Container(
                          width: k ? 10 : 8,
                          height: k ? 10 : 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? c.liveGreen
                                : past
                                ? c.textMuted.withValues(alpha: 0.3)
                                : c.primary,
                            shape: BoxShape.circle,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: c.liveGreen.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),

                      // Session info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.displayName,
                              style: GoogleFonts.inter(
                                color: isActive
                                    ? c.textPrimary
                                    : c.textPrimary.withValues(alpha: 0.9),
                                fontSize: k ? 24 : 17,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                            if (session.speaker != null) ...[
                              SizedBox(height: k ? 8 : 5),
                              Row(
                                children: [
                                  _SpeakerAvatar(
                                    speaker: session.speaker!,
                                    size: k ? 32 : 22,
                                  ),
                                  SizedBox(width: k ? 10 : 6),
                                  Expanded(
                                    child: Text(
                                      session.speaker!.name,
                                      style: GoogleFonts.inter(
                                        color: isActive
                                            ? c.textPrimary.withValues(
                                                alpha: 0.7,
                                              )
                                            : c.textMuted,
                                        fontSize: k ? 17 : 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (session.description != null &&
                                session.description!.isNotEmpty &&
                                isActive) ...[
                              SizedBox(height: k ? 8 : 5),
                              Text(
                                session.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: c.textPrimary.withValues(alpha: 0.45),
                                  fontSize: k ? 15 : 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Next Session Card ───────────────────────────────────────────────────────

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({
    required this.session,
    this.isKiosk = false,
    this.debugNow,
    this.colors = SchedulePanelColors.dark,
  });

  final EventSession session;
  final bool isKiosk;
  final DateTime? debugNow;
  final SchedulePanelColors colors;

  String _startsIn() {
    if (session.startAt == null) return '';
    final now = debugNow ?? DateTime.now();
    final diff = session.startAt!.difference(now);
    if (diff.isNegative) return 'Starting now';
    if (diff.inMinutes < 1) return 'Starts in < 1 min';
    if (diff.inMinutes < 60) return 'Starts in ${diff.inMinutes} min';
    return 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final k = isKiosk;
    final c = colors;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: k ? 16 : 12,
        vertical: k ? 6 : 4,
      ),
      padding: EdgeInsets.all(k ? 16 : 10),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.skip_next_rounded, color: c.gold, size: k ? 24 : 18),
          SizedBox(width: k ? 12 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UP NEXT',
                  style: GoogleFonts.inter(
                    color: c.gold,
                    fontSize: k ? 11 : 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.displayName,
                  style: GoogleFonts.inter(
                    color: c.textPrimary.withValues(alpha: 0.9),
                    fontSize: k ? 18 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (session.speaker != null)
                  Text(
                    session.speaker!.name,
                    style: GoogleFonts.inter(
                      color: c.textMuted,
                      fontSize: k ? 14 : 11,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: k ? 12 : 8,
              vertical: k ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _startsIn(),
              style: GoogleFonts.inter(
                color: c.gold,
                fontSize: k ? 13 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Speaker Avatar ──────────────────────────────────────────────────────────

class _SpeakerAvatar extends StatelessWidget {
  const _SpeakerAvatar({required this.speaker, this.size = 28});

  final SessionSpeaker speaker;
  final double size;

  static const _palette = [
    Color(0xFF6D4CFF),
    Color(0xFF3E7D4C),
    Color(0xFFE0B646),
    Color(0xFF4C7FE0),
    Color(0xFFE0614C),
    Color(0xFF4CE0C6),
    Color(0xFFB44CE0),
    Color(0xFFE04CAA),
  ];

  Color _colorFor(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final url = speaker.imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? (url.startsWith('assets/')
                  ? Image.asset(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildInitials(),
                    )
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, _) => _buildInitials(),
                      errorWidget: (_, _, _) => _buildInitials(),
                    ))
            : _buildInitials(),
      ),
    );
  }

  Widget _buildInitials() {
    final bg = _colorFor(speaker.name);
    return Container(
      color: bg.withValues(alpha: 0.85),
      child: Center(
        child: Text(
          _initials(speaker.name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.4,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

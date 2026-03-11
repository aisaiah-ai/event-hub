import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/firestore_config.dart';
import '../data/event_model.dart';

/// Live check-in panel that streams registrant data from Firestore.
/// Shows large counter, progress bar, check-in rate, and animated recent list.
class LiveCheckinPanel extends StatefulWidget {
  const LiveCheckinPanel({
    super.key,
    required this.event,
    this.isKiosk = false,
  });

  final EventModel event;
  final bool isKiosk;

  @override
  State<LiveCheckinPanel> createState() => _LiveCheckinPanelState();
}

class _LiveCheckinPanelState extends State<LiveCheckinPanel> {
  StreamSubscription? _defaultSub;
  StreamSubscription? _prodSub;
  Timer? _rateTicker;

  final Map<String, _RegistrantEntry> _registrantMap = {};
  final Set<String> _seenDefault = {};
  final Set<String> _seenProd = {};
  List<_RegistrantEntry> _registrants = [];

  // Animation: track newly added IDs
  final Set<String> _newIds = {};

  // Check-in rate: track timestamps of recent check-ins
  final List<DateTime> _recentCheckinTimes = [];
  double _checkinRate = 0;

  @override
  void initState() {
    super.initState();
    _startStream();
    // Recalculate rate every 30s
    _rateTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _calculateRate();
    });
  }

  @override
  void dispose() {
    _defaultSub?.cancel();
    _prodSub?.cancel();
    _rateTicker?.cancel();
    super.dispose();
  }

  void _startStream() {
    final fs = FirestoreConfig.instanceOrNull;
    if (fs == null) return;

    final eventId = widget.event.id;
    // Canonical doc ID for default DB (sessions/registrants stored under march-assembly)
    final defaultDocId = eventId == 'march-cluster-2026'
        ? 'march-assembly'
        : eventId;

    _defaultSub = fs
        .collection('events')
        .doc(defaultDocId)
        .collection('registrants')
        .snapshots()
        .listen(
          (snap) => _merge(snap.docs, 'default'),
          // ignore: avoid_print
          onError: (e) => print('[LiveCheckin] default stream error: $e'),
        );

    try {
      final prodDb = FirebaseFirestore.instanceFor(
        app: fs.app,
        databaseId: 'event-hub-prod',
      );
      final prodDocId = (defaultDocId == 'march-assembly')
          ? 'march-cluster-2026'
          : eventId;
      _prodSub = prodDb
          .collection('events')
          .doc(prodDocId)
          .collection('registrants')
          .snapshots()
          .listen(
            (snap) => _merge(snap.docs, 'prod'),
            // ignore: avoid_print
            onError: (e) => print('[LiveCheckin] prod stream error: $e'),
          );
    } catch (_) {}
  }

  void _merge(List<QueryDocumentSnapshot> docs, String source) {
    final seenSet = source == 'default' ? _seenDefault : _seenProd;
    seenSet.clear();

    for (final d in docs) {
      seenSet.add(d.id);
      final isNew = !_registrantMap.containsKey(d.id);
      final data = d.data() as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final name =
          profile['name'] as String? ??
          '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
      final additional = (data['additionalGuests'] as num?)?.toInt() ?? 0;
      final createdAt = data['createdAt'];
      DateTime created;
      if (createdAt is Timestamp) {
        created = createdAt.toDate();
      } else {
        created = DateTime.now();
      }
      final checkedIn = data['eventAttendance'] != null;
      _registrantMap[d.id] = _RegistrantEntry(
        id: d.id,
        name: name.isNotEmpty ? name : 'Guest',
        checkedIn: checkedIn,
        additionalGuests: additional,
        createdAt: created,
        source: data['source'] as String? ?? 'app',
        chapter: profile['chapter'] as String? ?? '',
      );
      if (isNew) {
        _newIds.add(d.id);
        if (checkedIn) _recentCheckinTimes.add(DateTime.now());
      }
    }

    final allIds = {..._seenDefault, ..._seenProd};
    _registrantMap.removeWhere((k, _) => !allIds.contains(k));

    final list = _registrantMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _registrants = list;
      });
      _calculateRate();
      // Clear new IDs after animation
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _newIds.clear());
      });
    }
  }

  void _calculateRate() {
    // Check-ins in the last 5 minutes
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _recentCheckinTimes.removeWhere((t) => t.isBefore(cutoff));
    final count = _recentCheckinTimes.length;
    setState(() {
      _checkinRate = count / 5.0; // per minute
    });
  }

  int get _totalRegistered {
    var total = _registrants.length;
    for (final r in _registrants) {
      total += r.additionalGuests;
    }
    return total;
  }

  int get _checkedInCount => _registrants.where((r) => r.checkedIn).length;

  @override
  Widget build(BuildContext context) {
    final k = widget.isKiosk;
    final total = _totalRegistered;
    final checkedIn = _checkedInCount;
    final pending = total - checkedIn;
    final fraction = total > 0 ? checkedIn / total : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
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
              k ? 14.0 : 10.0,
            ),
            child: Row(
              children: [
                Icon(Icons.how_to_reg_rounded, color: _gold, size: k ? 24 : 20),
                SizedBox(width: k ? 10 : 8),
                Text(
                  'Live Check-Ins',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: k ? 22 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _liveGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _liveGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          color: _liveGreen,
                          fontSize: k ? 12 : 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _cardBorder, height: 1),

          Expanded(
            child: ListView(
              padding: EdgeInsets.all(k ? 20 : 16),
              children: [
                // ── Large attendance counter ──
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: k ? 20 : 14,
                    horizontal: k ? 20 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222236),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _liveGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Big numbers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$checkedIn',
                            style: GoogleFonts.inter(
                              color: _liveGreen,
                              fontSize: k ? 56 : 42,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            ' / $total',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: k ? 28 : 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: k ? 6 : 4),
                      Text(
                        'Checked In',
                        style: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: k ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: k ? 14 : 10),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          minHeight: k ? 12 : 8,
                          backgroundColor: const Color(0xFF2A2A3A),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _liveGreen,
                          ),
                        ),
                      ),
                      SizedBox(height: k ? 8 : 6),
                      Text(
                        '$pct%',
                        style: GoogleFonts.inter(
                          color: _liveGreen,
                          fontSize: k ? 16 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: k ? 14 : 10),

                // ── Metric cards row ──
                Row(
                  children: [
                    Expanded(
                      child: _SmallMetric(
                        label: 'PENDING',
                        value: '$pending',
                        color: _gold,
                        icon: Icons.hourglass_bottom_rounded,
                        isKiosk: k,
                      ),
                    ),
                    SizedBox(width: k ? 10 : 8),
                    Expanded(
                      child: _SmallMetric(
                        label: 'RATE',
                        value: '${_checkinRate.toStringAsFixed(1)}/min',
                        color: const Color(0xFF4C7FE0),
                        icon: Icons.speed_rounded,
                        isKiosk: k,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: k ? 20 : 14),

                // ── Recent check-ins ──
                Text(
                  'RECENT ARRIVALS',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: k ? 12 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: k ? 10 : 6),

                // Animated list
                ...(_registrants.take(k ? 10 : 8).toList().asMap().entries.map((
                  entry,
                ) {
                  final r = entry.value;
                  final isNew = _newIds.contains(r.id);
                  return _AnimatedCheckinRow(
                    key: ValueKey(r.id),
                    entry: r,
                    isNew: isNew,
                    isKiosk: k,
                  );
                })),

                SizedBox(height: k ? 20 : 14),

                // ── QR Reminder ──
                Container(
                  padding: EdgeInsets.all(k ? 14 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222236),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: _gold,
                        size: k ? 28 : 22,
                      ),
                      SizedBox(width: k ? 12 : 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan to Check In',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: k ? 14 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'events.aisaiah.org/s/mca',
                              style: GoogleFonts.inter(
                                color: _gold,
                                fontSize: k ? 12 : 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _cardBg = Color(0xFF1A1A2A);
  static const _cardBorder = Color(0xFF2A2A3A);
  static const _gold = Color(0xFFF4A340);
  static const _liveGreen = Color(0xFF7AE3A5);
  static const _textMuted = Color(0xFF8888A0);
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _RegistrantEntry {
  const _RegistrantEntry({
    required this.id,
    required this.name,
    required this.checkedIn,
    required this.additionalGuests,
    required this.createdAt,
    required this.source,
    required this.chapter,
  });

  final String id;
  final String name;
  final bool checkedIn;
  final int additionalGuests;
  final DateTime createdAt;
  final String source;
  final String chapter;
}

// ─── Small Metric Card ────────────────────────────────────────────────────────

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isKiosk = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isKiosk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isKiosk ? 14 : 10,
        horizontal: isKiosk ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF222236),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isKiosk ? 22 : 18),
          SizedBox(width: isKiosk ? 10 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isKiosk ? 20 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8888A0),
                    fontSize: isKiosk ? 10 : 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
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

// ─── Animated Check-in Row (slide + fade) ─────────────────────────────────────

class _AnimatedCheckinRow extends StatefulWidget {
  const _AnimatedCheckinRow({
    super.key,
    required this.entry,
    this.isNew = false,
    this.isKiosk = false,
  });

  final _RegistrantEntry entry;
  final bool isNew;
  final bool isKiosk;

  @override
  State<_AnimatedCheckinRow> createState() => _AnimatedCheckinRowState();
}

class _AnimatedCheckinRowState extends State<_AnimatedCheckinRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isNew) {
      // Start hidden, then animate in
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.entry;
    final k = widget.isKiosk;
    final initials = _getInitials(r.name);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: k ? 5 : 3),
          child: Row(
            children: [
              // Status icon
              Icon(
                r.checkedIn
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: k ? 18 : 14,
                color: r.checkedIn
                    ? const Color(0xFF7AE3A5) // green
                    : const Color(0xFFF4A340), // yellow/pending
              ),
              SizedBox(width: k ? 10 : 8),
              // Avatar
              CircleAvatar(
                radius: k ? 18 : 14,
                backgroundColor: _colorFor(r.name),
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: k ? 11 : 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: k ? 10 : 8),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: k ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isNew && r.checkedIn)
                      Text(
                        'just checked in',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7AE3A5).withValues(alpha: 0.7),
                          fontSize: k ? 11 : 9,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Time
              Text(
                _timeAgo(r.createdAt),
                style: GoogleFonts.inter(
                  color: const Color(0xFF8888A0),
                  fontSize: k ? 11 : 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

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

  static Color _colorFor(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return _palette[hash % _palette.length];
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/firestore_config.dart';
import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../widgets/event_page_scaffold.dart';

/// Check-In Dashboard — live-updating summary of event check-ins.
///
/// Route: /events/:eventSlug/checkin-dashboard
class CheckinDashboardPage extends StatefulWidget {
  const CheckinDashboardPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<CheckinDashboardPage> createState() => _CheckinDashboardPageState();
}

class _CheckinDashboardPageState extends State<CheckinDashboardPage> {
  final _repo = EventRepository();
  EventModel? _event;
  bool _loading = true;
  String? _error;

  // Live data
  List<Map<String, dynamic>> _registrants = [];
  StreamSubscription? _registrantsSub;
  StreamSubscription? _registrantsProdSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _registrantsSub?.cancel();
    _registrantsProdSub?.cancel();
    super.dispose();
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
      _startLiveUpdates(event.id);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _startLiveUpdates(String eventId) {
    _registrantsSub?.cancel();
    _registrantsProdSub?.cancel();

    final fs = FirestoreConfig.instanceOrNull;
    if (fs == null) return;

    // Listen to default database
    _registrantsSub = fs
        .collection('events')
        .doc(eventId)
        .collection('registrants')
        .snapshots()
        .listen((snap) {
      _mergeRegistrants(snap.docs, 'default');
    });

    // Listen to prod database
    try {
      final prodDb = FirebaseFirestore.instanceFor(
        app: fs.app,
        databaseId: 'event-hub-prod',
      );
      final prodDocId =
          eventId == 'march-assembly' ? 'march-cluster-2026' : eventId;
      _registrantsProdSub = prodDb
          .collection('events')
          .doc(prodDocId)
          .collection('registrants')
          .snapshots()
          .listen((snap) {
        _mergeRegistrants(snap.docs, 'prod');
      });
    } catch (_) {}
  }

  final Map<String, Map<String, dynamic>> _registrantMap = {};
  final Set<String> _seenDefault = {};
  final Set<String> _seenProd = {};

  void _mergeRegistrants(List<QueryDocumentSnapshot> docs, String source) {
    final seenSet = source == 'default' ? _seenDefault : _seenProd;
    seenSet.clear();

    for (final d in docs) {
      seenSet.add(d.id);
      if (_registrantMap.containsKey(d.id)) continue;
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
      final hasAttendance = data['eventAttendance'] != null;
      _registrantMap[d.id] = {
        'id': d.id,
        'name': name,
        'source': data['source'] as String? ?? 'app',
        'service': profile['service'] as String? ?? '',
        'chapter': profile['chapter'] as String? ?? '',
        'additionalGuests': additional,
        'createdAt': created,
        'checkedIn': hasAttendance,
      };
    }

    // Rebuild list
    final allIds = {..._seenDefault, ..._seenProd};
    _registrantMap.removeWhere((k, _) => !allIds.contains(k));

    final list = _registrantMap.values.toList()
      ..sort(
        (a, b) =>
            (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
      );

    if (mounted) {
      setState(() {
        _registrants = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: _event,
      eventSlug: widget.eventSlug,
      bodyMaxWidth: 720,
      overlayOpacity: 0.78,
      overlayTint: const Color(0xFF0A0A14),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _gold,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: _buildDashboard(),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _gold, size: 48),
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
            style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _gold),
            label: Text('Retry', style: GoogleFonts.inter(color: _gold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = _CheckinStats.compute(_registrants);
    final event = _event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(event),
        const SizedBox(height: 12),
        // Live indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _liveGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE',
              style: GoogleFonts.inter(
                color: _liveGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionLabel('OVERVIEW'),
        const SizedBox(height: 12),
        _buildOverviewCards(stats),
        const SizedBox(height: 28),
        _buildSectionLabel('CHECK-IN PROGRESS'),
        const SizedBox(height: 12),
        _buildProgressCard(stats),
        const SizedBox(height: 28),
        _buildSectionLabel('BY SOURCE'),
        const SizedBox(height: 12),
        _buildSourceBreakdown(stats),
        if (stats.byChapter.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildSectionLabel('BY CHAPTER'),
          const SizedBox(height: 12),
          _buildChapterCards(stats),
        ],
        const SizedBox(height: 28),
        _buildSectionLabel('RECENT CHECK-INS'),
        const SizedBox(height: 12),
        _buildRecentCheckins(),
        const SizedBox(height: 32),
        _buildFooter(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader(EventModel? event) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (event != null)
              EventLogo(logoUrl: event.effectiveLogoUrl, size: 80),
            if (event != null) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event?.organizationName?.toUpperCase() ??
                        'CENTRAL B CLUSTER \u00B7 COUPLES FOR CHRIST',
                    style: GoogleFonts.inter(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event?.name ?? 'Event',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_liveGreen, Color(0xFF2ECC71)],
                    ).createShader(bounds),
                    child: Text(
                      'Check-In Dashboard',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\uD83D\uDCC5', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                event != null
                    ? '${DateFormat('MMMM d, yyyy').format(event.startDate)} \u00B7 ${event.locationName}'
                    : '',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCards(_CheckinStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final cards = [
          _OverviewTile(
            icon: Icons.people_alt_rounded,
            iconColor: _liveGreen,
            value: stats.totalRegistrants,
            label: 'TOTAL REGISTERED',
            highlighted: true,
            highlightColor: _liveGreen,
          ),
          _OverviewTile(
            icon: Icons.check_circle_rounded,
            iconColor: _gold,
            value: stats.checkedInCount,
            label: 'CHECKED IN',
          ),
          _OverviewTile(
            icon: Icons.hourglass_bottom_rounded,
            iconColor: const Color(0xFFB0B0B0),
            value: stats.totalRegistrants - stats.checkedInCount,
            label: 'PENDING',
          ),
          _OverviewTile(
            icon: Icons.group_add_rounded,
            iconColor: const Color(0xFF4C7FE0),
            value: stats.additionalGuests,
            label: 'EXTRA GUESTS',
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards
              .map(
                (c) =>
                    SizedBox(width: (constraints.maxWidth - 8) / 2, child: c),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildProgressCard(_CheckinStats stats) {
    final fraction = stats.totalRegistrants > 0
        ? stats.checkedInCount / stats.totalRegistrants
        : 0.0;
    final pct = (fraction * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        color: _liveGreen,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${stats.checkedInCount} of ${stats.totalRegistrants} checked in',
                      style: GoogleFonts.inter(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 8,
                      backgroundColor: _cardBorder,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_liveGreen),
                    ),
                    Center(
                      child: Icon(
                        Icons.how_to_reg_rounded,
                        color: _liveGreen,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: _cardBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(_liveGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBreakdown(_CheckinStats stats) {
    final maxVal = stats.bySource.values
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, double.maxFinite.toInt());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: stats.bySource.entries.map((e) {
          final label = _sourceLabel(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BarRow(
              label: label,
              value: e.value,
              maxValue: maxVal,
              color: _sourceColor(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChapterCards(_CheckinStats stats) {
    final chapters = stats.byChapter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        if (isWide) {
          return Row(
            children: chapters
                .map(
                  (e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ChapterCard(name: e.key, count: e.value),
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chapters
              .map(
                (e) => SizedBox(
                  width: chapters.length <= 2
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 16) / 3,
                  child: _ChapterCard(name: e.key, count: e.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildRecentCheckins() {
    final recent = _registrants.take(10).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Text(
          'No registrants yet',
          style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            _RecentCheckinRow(data: recent[i]),
            if (i < recent.length - 1)
              Divider(
                color: _cardBorder,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(color: _textMuted, fontSize: 12),
            children: [
              const TextSpan(text: 'Events powered by '),
              TextSpan(
                text: 'Aisaiah',
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live dashboard \u00B7 ${DateFormat('MMMM yyyy').format(DateTime.now())} \u00B7 ${_registrants.length} registrants',
          style: GoogleFonts.inter(
            color: _textMuted.withValues(alpha: 0.5),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: _textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }

  static BoxDecoration _cardDecoration() => BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      );

  String _sourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'app':
        return 'App Registration';
      case 'manual':
        return 'Manual Entry';
      case 'qr':
        return 'QR Code';
      case 'web':
        return 'Web Form';
      default:
        return source;
    }
  }

  Color _sourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'app':
        return _gold;
      case 'manual':
        return const Color(0xFF4C7FE0);
      case 'qr':
        return _liveGreen;
      case 'web':
        return const Color(0xFFE87D2E);
      default:
        return _textMuted;
    }
  }

  static const Color _gold = Color(0xFFF4A340);
  static const Color _liveGreen = Color(0xFF7AE3A5);
  static const Color _cardBg = Color(0xFF1A1A2A);
  static const Color _cardBorder = Color(0xFF2A2A3A);
  static const Color _textMuted = Color(0xFF8888A0);
}

// ══════════════════════════════════════════════════════════════════════════
// Stats
// ══════════════════════════════════════════════════════════════════════════

class _CheckinStats {
  final int totalRegistrants;
  final int checkedInCount;
  final int additionalGuests;
  final Map<String, int> bySource;
  final Map<String, int> byChapter;

  const _CheckinStats({
    required this.totalRegistrants,
    required this.checkedInCount,
    required this.additionalGuests,
    required this.bySource,
    required this.byChapter,
  });

  factory _CheckinStats.compute(List<Map<String, dynamic>> registrants) {
    var total = registrants.length;
    var checkedIn = 0;
    var additional = 0;
    final bySource = <String, int>{};
    final byChapter = <String, int>{};

    for (final r in registrants) {
      additional += (r['additionalGuests'] as int? ?? 0);
      if (r['checkedIn'] == true) checkedIn++;

      final source = (r['source'] as String?) ?? 'app';
      bySource[source] = (bySource[source] ?? 0) + 1;

      final chapter = (r['chapter'] as String?) ?? '';
      if (chapter.isNotEmpty) {
        byChapter[chapter] = (byChapter[chapter] ?? 0) + 1;
      }
    }

    total += additional;

    return _CheckinStats(
      totalRegistrants: total,
      checkedInCount: checkedIn,
      additionalGuests: additional,
      bySource: bySource,
      byChapter: byChapter,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.highlighted = false,
    this.highlightColor,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;
  final bool highlighted;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final accent = highlightColor ?? const Color(0xFFF4A340);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.5)
              : const Color(0xFF2A2A3A),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: highlighted ? accent : Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8888A0),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 10,
              backgroundColor: const Color(0xFF2A2A3A),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\uD83D\uDCCD', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: const Color(0xFF7AE3A5),
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'PEOPLE',
            style: GoogleFonts.inter(
              color: const Color(0xFF8888A0),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCheckinRow extends StatelessWidget {
  const _RecentCheckinRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final initials = _getInitials(name);
    final checkedIn = data['checkedIn'] as bool? ?? false;
    final source = data['source'] as String? ?? '';
    final createdAt = data['createdAt'] as DateTime?;
    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _colorFor(name),
            child: Text(
              initials,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (checkedIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7AE3A5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Checked In',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7AE3A5),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4A340).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Registered',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF4A340),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (source.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF4C7FE0).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          source,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF4C7FE0),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: GoogleFonts.inter(
              color: const Color(0xFF8888A0),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/event_model.dart';
import '../data/event_repository.dart';
import '../data/event_rsvp.dart';
import '../widgets/event_page_scaffold.dart';

/// RSVP Snapshot Dashboard — **light-themed** version for projector display.
///
/// Route: /events/:eventSlug/rsvp-dashboard-light
class RsvpDashboardLightPage extends StatefulWidget {
  const RsvpDashboardLightPage({super.key, required this.eventSlug});

  final String eventSlug;

  @override
  State<RsvpDashboardLightPage> createState() => _RsvpDashboardLightPageState();
}

class _RsvpDashboardLightPageState extends State<RsvpDashboardLightPage> {
  final _repo = EventRepository();
  EventModel? _event;
  List<EventRsvp> _rsvps = [];
  List<Map<String, dynamic>> _registrants = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _repo.listRsvps(event.id),
        _repo.listRegistrants(event.id),
      ]);
      final rsvps = results[0] as List<EventRsvp>;
      final regs = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _event = event;
        _rsvps = rsvps;
        _registrants = regs;
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
    return Scaffold(
      backgroundColor: _bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _load,
              color: _accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildDashboard(),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _accent, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard',
            style: GoogleFonts.inter(
              color: _textPrimary,
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
            icon: const Icon(Icons.refresh, color: _accent),
            label: Text('Retry', style: GoogleFonts.inter(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = _RsvpStats.compute(_rsvps, _registrants);
    final event = _event;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(event),
        const SizedBox(height: 32),
        _buildSectionLabel('OVERVIEW'),
        const SizedBox(height: 12),
        _buildOverviewCards(stats),
        const SizedBox(height: 28),
        _buildSectionLabel('ATTENDANCE BREAKDOWN'),
        const SizedBox(height: 12),
        _buildAttendanceBreakdown(stats),
        const SizedBox(height: 28),
        _buildSectionLabel('BY AREA'),
        const SizedBox(height: 12),
        _buildAreaCards(stats),
        if (stats.kidsCount > 0) ...[
          const SizedBox(height: 28),
          _buildSectionLabel('KIDS'),
          const SizedBox(height: 12),
          _buildKidsCard(stats),
        ],
        const SizedBox(height: 28),
        _buildSectionLabel('RECENT RSVPs'),
        const SizedBox(height: 12),
        _buildRecentRsvps(),
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
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event?.name ?? 'Event',
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'RSVP Snapshot',
                    style: GoogleFonts.inter(
                      color: _accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (event?.shortDescription != null)
          Text(
            event!.shortDescription!,
            style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
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
                  color: _textPrimary,
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

  Widget _buildOverviewCards(_RsvpStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        final cards = [
          _OverviewTile(
            icon: Icons.groups_rounded,
            iconColor: _accent,
            value: stats.totalAttendees,
            label: 'TOTAL RSVPs',
            highlighted: true,
          ),
          _OverviewTile(
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFF666666),
            value: stats.rallyCount,
            label: 'RALLY',
          ),
          _OverviewTile(
            icon: Icons.restaurant_rounded,
            iconColor: const Color(0xFF666666),
            value: stats.dinnerCount,
            label: 'DINNER',
          ),
          _OverviewTile(
            icon: Icons.celebration_rounded,
            iconColor: const Color(0xFFD06820),
            value: stats.celebrationCount,
            label: 'CELEBRATIONS',
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

  Widget _buildAttendanceBreakdown(_RsvpStats stats) {
    final maxVal = [
      stats.rallyCount,
      stats.dinnerCount,
      stats.celebrationCount,
    ].reduce((a, b) => a > b ? a : b).clamp(1, double.maxFinite.toInt());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _BarRow(
            label: 'Rally',
            time: _event?.rallyTimeText,
            value: stats.rallyCount,
            maxValue: maxVal,
            color: _accent,
          ),
          const SizedBox(height: 14),
          _BarRow(
            label: 'Dinner',
            time: _event?.dinnerTimeText,
            value: stats.dinnerCount,
            maxValue: maxVal,
            color: const Color(0xFF3366CC),
          ),
          const SizedBox(height: 14),
          _BarRow(
            label: 'Celebrations',
            value: stats.celebrationCount,
            maxValue: maxVal,
            color: const Color(0xFFD06820),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCards(_RsvpStats stats) {
    final areas = stats.byArea.entries.toList()
      ..sort((a, b) => b.value.people.compareTo(a.value.people));

    if (areas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Text(
          'No area data yet',
          style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        if (isWide) {
          return Row(
            children: areas
                .map(
                  (e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _AreaCard(name: e.key, data: e.value),
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: areas
              .map(
                (e) => SizedBox(
                  width: areas.length <= 2
                      ? (constraints.maxWidth - 8) / 2
                      : (constraints.maxWidth - 16) / 3,
                  child: _AreaCard(name: e.key, data: e.value),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKidsCard(_RsvpStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2B9E8C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: Color(0xFF2B9E8C),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.kidsCount}',
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  stats.kidsCount == 1 ? 'CHILD REGISTERED' : 'KIDS REGISTERED',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 11,
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

  Widget _buildRecentRsvps() {
    final recent = _registrants.take(8).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Text(
          'No RSVPs yet',
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
            _RecentRegistrantRow(registrant: recent[i]),
            if (i < recent.length - 1)
              Divider(color: _cardBorder, height: 1, indent: 16, endIndent: 16),
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
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Report generated \u00B7 ${DateFormat('MMMM yyyy').format(DateTime.now())} \u00B7 ${_registrants.length} registrants on record',
          style: GoogleFonts.inter(
            color: _textMuted.withValues(alpha: 0.7),
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

  // ── Light Color Tokens ─────────────────────────────────────────────
  static const Color _bgColor = Color(0xFFF5F5F0);
  static const Color _accent = Color(0xFFD48A20);
  static const Color _cardBg = Colors.white;
  static const Color _cardBorder = Color(0xFFE0E0D8);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF888880);
}

// ══════════════════════════════════════════════════════════════════════════
// Data model (same as dark version)
// ══════════════════════════════════════════════════════════════════════════

class _AreaData {
  int people = 0;
  final Set<String> households = {};
}

class _RsvpStats {
  final int totalAttendees;
  final int rallyCount;
  final int dinnerCount;
  final int celebrationCount;
  final int kidsCount;
  final int registrantCount;
  final int registrantCheckedIn;
  final Map<String, _AreaData> byArea;

  const _RsvpStats({
    required this.totalAttendees,
    required this.rallyCount,
    required this.dinnerCount,
    required this.celebrationCount,
    required this.kidsCount,
    required this.registrantCount,
    required this.registrantCheckedIn,
    required this.byArea,
  });

  factory _RsvpStats.compute(
    List<EventRsvp> rsvps,
    List<Map<String, dynamic>> registrants,
  ) {
    var totalAttendees = 0;
    var rallyCount = 0;
    var dinnerCount = 0;
    var celebrationCount = 0;
    var kidsCount = 0;
    final byArea = <String, _AreaData>{};

    for (final r in rsvps) {
      totalAttendees += r.attendeesCount;
      if (r.attendingRally) rallyCount += r.attendeesCount;
      if (r.attendingDinner) dinnerCount += r.attendeesCount;
      if (r.celebrationType != null && r.celebrationType!.isNotEmpty) {
        celebrationCount++;
      }
      kidsCount += r.kids.length;

      final area = r.area ?? 'Others';
      final areaData = byArea.putIfAbsent(area, () => _AreaData());
      areaData.people += r.attendeesCount;
      if (r.household.isNotEmpty) areaData.households.add(r.household);
    }

    var regCount = 0;
    var regCheckedIn = 0;
    for (final r in registrants) {
      regCount++;
      regCount += (r['additionalGuests'] as int? ?? 0);
      if (r['checkedIn'] == true) regCheckedIn++;

      final attendingRally = r['attendingRally'] as bool? ?? false;
      final attendingDinner = r['attendingDinner'] as bool? ?? false;
      if (attendingRally) rallyCount++;
      if (attendingDinner) dinnerCount++;

      final celebration = r['celebrationType'] as String? ?? '';
      if (celebration.isNotEmpty) celebrationCount++;

      final kids = r['kids'] as List<dynamic>? ?? [];
      kidsCount += kids.length;

      final area = r['area'] as String? ?? '';
      if (area.isNotEmpty) {
        final areaData = byArea.putIfAbsent(area, () => _AreaData());
        areaData.people++;
        final household = r['household'] as String? ?? '';
        if (household.isNotEmpty) areaData.households.add(household);
      }
    }

    return _RsvpStats(
      totalAttendees: totalAttendees + regCount,
      rallyCount: rallyCount,
      dinnerCount: dinnerCount,
      celebrationCount: celebrationCount,
      kidsCount: kidsCount,
      registrantCount: regCount,
      registrantCheckedIn: regCheckedIn,
      byArea: byArea,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Sub-widgets (light themed)
// ══════════════════════════════════════════════════════════════════════════

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFD48A20).withValues(alpha: 0.5)
              : const Color(0xFFE0E0D8),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: highlighted
                  ? const Color(0xFFD48A20)
                  : const Color(0xFF1A1A1A),
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF888880),
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
    this.time,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final String? time;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue > 0 ? value / maxValue : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            time != null ? '$label ($time)' : label,
            style: GoogleFonts.inter(
              color: const Color(0xFF1A1A1A),
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
              backgroundColor: const Color(0xFFE8E8E0),
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
              color: const Color(0xFF1A1A1A),
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

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.name, required this.data});

  final String name;
  final _AreaData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: const Color(0xFF1A1A1A),
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
            '${data.people}',
            style: GoogleFonts.inter(
              color: const Color(0xFFD48A20),
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'PEOPLE',
            style: GoogleFonts.inter(
              color: const Color(0xFF888880),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${data.households.length} household${data.households.length == 1 ? '' : 's'}',
              style: GoogleFonts.inter(
                color: const Color(0xFF888880),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRegistrantRow extends StatelessWidget {
  const _RecentRegistrantRow({required this.registrant});

  final Map<String, dynamic> registrant;

  @override
  Widget build(BuildContext context) {
    final name = registrant['name'] as String? ?? '';
    final initials = _getInitials(name);
    final badges = <Widget>[];
    if (registrant['attendingRally'] == true) {
      badges.add(_badge('Rally', const Color(0xFFD48A20)));
    }
    if (registrant['attendingDinner'] == true) {
      badges.add(_badge('Dinner', const Color(0xFF3366CC)));
    }
    final celebration = registrant['celebrationType'] as String? ?? '';
    if (celebration.isNotEmpty) {
      badges.add(_badge(celebration, const Color(0xFFD06820)));
    }
    final source = registrant['source'] as String? ?? '';
    if (source == 'app') {
      badges.add(_badge('Registered', const Color(0xFF2B9E8C)));
    }

    final area = registrant['area'] as String? ?? '';

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
                    color: const Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 4, children: badges),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${registrant['attendeesCount'] ?? 1}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (area.isNotEmpty)
                Text(
                  area,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF888880),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

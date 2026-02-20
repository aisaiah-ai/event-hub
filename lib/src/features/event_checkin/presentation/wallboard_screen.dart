import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/nlc_theme.dart';
import '../../../core/theme/session_colors.dart';
import '../../../theme/nlc_palette.dart';
import '../../../models/analytics_aggregates.dart';
import '../../../models/session.dart';
import '../../../services/checkin_analytics_service.dart';
import '../../../services/dashboard_layout_service.dart';
import '../../../widgets/rolling_counter.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'widgets/hourly_trend_chart.dart';
import 'widgets/last_updated_with_timezone.dart';

/// Full-screen wallboard display mode for projectors, LED walls, lobby monitors.
/// Auto-refreshing, no admin controls, large typography, rolling counter animations.
/// Reads ONLY from analytics/global and sessions/*/analytics/summary.
class WallboardScreen extends StatefulWidget {
  const WallboardScreen({
    super.key,
    required this.eventId,
    this.eventTitle = 'Event',
    this.eventVenue,
  });

  final String eventId;
  final String eventTitle;
  final String? eventVenue;

  @override
  State<WallboardScreen> createState() => _WallboardScreenState();
}

class _WallboardScreenState extends State<WallboardScreen> {
  bool _showWaitingHint = false;
  bool _isEditLayout = false;
  List<String>? _localWallboardOrder;
  late final CheckinAnalyticsService _analyticsService;
  late final DashboardLayoutService _layoutService;
  late final Stream<GlobalAnalytics> _globalStream;
  late final Stream<List<SessionCheckinStat>> _sessionStream;
  late final Stream<List<String>> _layoutStream;

  @override
  void initState() {
    super.initState();
    _analyticsService = CheckinAnalyticsService();
    _layoutService = DashboardLayoutService();
    _globalStream = _analyticsService.watchGlobalAnalytics(widget.eventId);
    _sessionStream = _analyticsService.watchSessionCheckins(widget.eventId);
    _layoutStream = _layoutService.watchWallboardOrder(widget.eventId);
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) setState(() => _showWaitingHint = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return EventPageScaffold(
      event: null,
      eventSlug: widget.eventId.contains('nlc') ? 'nlc' : null,
      bodyMaxWidth: 1600,
      overlayOpacity: 0.65,
      appBar: null,
      body: StreamBuilder<GlobalAnalytics>(
        stream: _globalStream,
        builder: (context, globalSnap) {
          return StreamBuilder<List<SessionCheckinStat>>(
            stream: _sessionStream,
            builder: (context, sessSnap) {
              // Show loading only on initial load. Keep content during refresh.
              if ((!globalSnap.hasData || !sessSnap.hasData) &&
                  (globalSnap.connectionState == ConnectionState.waiting ||
                      sessSnap.connectionState == ConnectionState.waiting)) {
                return const _WallboardLoading();
              }
              final global = globalSnap.data ?? const GlobalAnalytics();
              final sessions = sessSnap.data ?? [];
              final lastUpdated = global.lastUpdated ?? DateTime.now();
              final registrantCount = global.totalRegistrants;

              return _WallboardContent(
                eventId: widget.eventId,
                eventTitle: widget.eventTitle,
                eventVenue: widget.eventVenue,
                global: global,
                sessions: sessions,
                lastUpdated: lastUpdated,
                layoutStream: _layoutStream,
                showWaitingHint: _showWaitingHint,
                isEditLayout: _isEditLayout,
                localWallboardOrder: _localWallboardOrder,
                onEditLayout: () => setState(() {
                  _isEditLayout = !_isEditLayout;
                  // Keep _localWallboardOrder after exit so layout persists when Firestore fails
                }),
                onReorder: (newOrder) {
                  setState(() => _localWallboardOrder = newOrder);
                  _layoutService.saveWallboardOrder(widget.eventId, newOrder);
                },
                registrantCount: registrantCount,
              );
            },
          );
        },
      ),
    );
  }
}

class _WallboardLoading extends StatelessWidget {
  const _WallboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: NlcPalette.brandBlue),
          const SizedBox(height: 24),
          Text(
            'Loading live data…',
            style: GoogleFonts.inter(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Theme (NlcColors) ---

BoxDecoration _wbCardDecoration() => BoxDecoration(
      color: NlcColors.ivory,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// Wallboard metric tile: ivory, 16px radius, stronger shadow.
BoxDecoration _wbMetricTileDecoration() => BoxDecoration(
      color: NlcColors.ivory,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );

// --- Content ---

class _WallboardContent extends StatelessWidget {
  const _WallboardContent({
    required this.eventId,
    required this.eventTitle,
    this.eventVenue,
    required this.global,
    required this.sessions,
    required this.lastUpdated,
    required this.layoutStream,
    required this.registrantCount,
    required this.showWaitingHint,
    required this.isEditLayout,
    this.localWallboardOrder,
    required this.onEditLayout,
    required this.onReorder,
  });

  final String eventId;
  final String eventTitle;
  final String? eventVenue;
  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final DateTime lastUpdated;
  final int registrantCount;
  final Stream<List<String>> layoutStream;
  final bool showWaitingHint;
  final bool isEditLayout;
  final List<String>? localWallboardOrder;
  final VoidCallback onEditLayout;
  final void Function(List<String>) onReorder;

  String get _displayTitle {
    if (eventTitle.isNotEmpty && eventTitle != 'Event') return eventTitle;
    if (eventId.contains('nlc')) return 'NLC Dashboard';
    return 'NLC Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WallboardConferenceTitle(
                  title: _displayTitle,
                  venue: eventVenue,
                ),
                _WallboardHeader(
                  lastUpdated: lastUpdated,
                  showWaitingHint: showWaitingHint,
                  isEditLayout: isEditLayout,
                  onEditLayout: onEditLayout,
                ),
                const SizedBox(height: 40),
                StreamBuilder<List<String>>(
                  stream: layoutStream,
                  initialData: kDefaultWallboardOrder,
                  builder: (context, orderSnap) {
                    final streamOrder = orderSnap.data ?? kDefaultWallboardOrder;
                    final order = localWallboardOrder ?? streamOrder;
                    if (isEditLayout) {
                      return _ReorderableWallboardSections(
                        order: order,
                        global: global,
                        sessions: sessions,
                        registrantCount: registrantCount,
                        onReorder: onReorder,
                      );
                    }
                    return _WallboardSectionsInOrder(
                      order: order,
                      global: global,
                      sessions: sessions,
                      registrantCount: registrantCount,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildWallboardSection(
  String sectionId,
  GlobalAnalytics global,
  List<SessionCheckinStat> sessions, {
  required int registrantCount,
}) {
  const mainCheckinId = 'main-checkin';
  final totalExcludingMain = sessions
      .where((s) => s.sessionId != mainCheckinId)
      .fold<int>(0, (sum, s) => sum + (s.checkInCount.clamp(0, 0x7FFFFFFF)));

  switch (sectionId) {
    case 'metrics':
      return _WallboardMetrics(
        global: global,
        sessions: sessions,
        registrantCount: registrantCount,
      );
    case 'graph':
      return _WallboardGraph(global: global);
    case 'leaderboard':
      return _WallboardLeaderboard(
        sessions: sessions,
        totalCheckins: totalExcludingMain,
        mainCheckinSessionId: mainCheckinId,
      );
    default:
      return const SizedBox.shrink();
  }
}

class _WallboardSectionsInOrder extends StatelessWidget {
  const _WallboardSectionsInOrder({
    required this.order,
    required this.global,
    required this.sessions,
    required this.registrantCount,
  });

  final List<String> order;
  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final int registrantCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in order) ...[
          _buildWallboardSection(id, global, sessions, registrantCount: registrantCount),
          const SizedBox(height: 40),
        ],
      ],
    );
  }
}

class _ReorderableWallboardSections extends StatelessWidget {
  const _ReorderableWallboardSections({
    required this.order,
    required this.global,
    required this.sessions,
    required this.registrantCount,
    required this.onReorder,
  });

  final List<String> order;
  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final int registrantCount;
  final void Function(List<String>) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex--;
        final updated = List<String>.from(order);
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);
        onReorder(updated);
      },
      children: [
        for (var i = 0; i < order.length; i++)
          Padding(
            key: ValueKey(order[i]),
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  child: ReorderableDragStartListener(
                    index: i,
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.white.withOpacity(0.7),
                      size: 28,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildWallboardSection(
                    order[i],
                    global,
                    sessions,
                    registrantCount: registrantCount,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Conference title ---

class _WallboardConferenceTitle extends StatelessWidget {
  const _WallboardConferenceTitle({required this.title, this.venue});

  final String title;
  final String? venue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          if (venue != null && venue!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              venue!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Header ---

class _WallboardHeader extends StatelessWidget {
  const _WallboardHeader({
    required this.lastUpdated,
    required this.showWaitingHint,
    required this.isEditLayout,
    required this.onEditLayout,
  });

  final DateTime lastUpdated;
  final bool showWaitingHint;
  final bool isEditLayout;
  final VoidCallback onEditLayout;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.9)),
          tooltip: 'More options',
          onSelected: (_) => onEditLayout(),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'editLayout',
              child: Text(isEditLayout ? 'Done editing layout' : 'Edit layout'),
            ),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _LiveIndicator(),
            const SizedBox(height: 8),
            LastUpdatedWithTimezone(
              lastUpdated: lastUpdated,
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            if (showWaitingHint) ...[
              const SizedBox(height: 4),
              Text(
                'Waiting for updates…',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NlcColors.successGreen
                  .withOpacity(0.6 + 0.4 * _controller.value),
              boxShadow: [
                BoxShadow(
                  color: NlcColors.successGreen.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'LIVE',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: NlcColors.successGreen,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// --- Big Metrics Row ---

class _WallboardMetrics extends StatelessWidget {
  const _WallboardMetrics({
    required this.global,
    required this.sessions,
    required this.registrantCount,
  });

  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final int registrantCount;

  @override
  Widget build(BuildContext context) {
    const mainCheckinId = 'main-checkin';
    final mainCheckin = sessions.where((s) => s.sessionId == mainCheckinId).firstOrNull;
    final mainCheckinCount = (mainCheckin?.checkInCount ?? 0).clamp(0, 0x7FFFFFFF);
    final sessionCheckins = sessions
        .where((s) => s.sessionId != mainCheckinId)
        .fold<int>(0, (sum, s) => sum + (s.checkInCount.clamp(0, 0x7FFFFFFF)));

    final tiles = [
      _WallboardMetricTile(
        icon: Icons.people_rounded,
        label: 'Total Registrants',
        value: registrantCount.clamp(0, 0x7FFFFFFF),
      ),
      _WallboardMetricTile(
        icon: Icons.check_circle_rounded,
        label: 'Main Check-In Total',
        value: mainCheckinCount,
        subtext: 'Main Conference Entry',
      ),
      _WallboardMetricTile(
        icon: Icons.bar_chart_rounded,
        label: 'Session Check-Ins',
        value: sessionCheckins,
        subtext: 'Breakout Sessions Only',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: tiles,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 24),
            Expanded(child: tiles[1]),
            const SizedBox(width: 24),
            Expanded(child: tiles[2]),
          ],
        );
      },
    );
  }
}

class _WallboardMetricTile extends StatelessWidget {
  const _WallboardMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
  });

  final IconData icon;
  final String label;
  final int value;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.clamp(0, 0x7FFFFFFF);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _wbMetricTileDecoration(),
      child: SizedBox(
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: NlcPalette.brandBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NlcColors.slate,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.black.withOpacity(0.08),
            ),
            RollingCounter(
              value: displayValue,
              duration: const Duration(milliseconds: 2200),
              exaggerated: true,
              enableGlow: true,
              showDelta: true,
              style: GoogleFonts.inter(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: NlcColors.slate,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: NlcPalette.brandBlue.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: NlcColors.mutedText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Large Graph ---

class _WallboardGraph extends StatelessWidget {
  const _WallboardGraph({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _wbCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check-In Trend',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: NlcColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hourly Attendance Progress',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: NlcColors.mutedText,
            ),
          ),
          const SizedBox(height: 24),
          HourlyTrendChart(
            hourlyCheckins: global.hourlyCheckins,
            height: 380,
            lineColor: NlcPalette.brandBlue,
            emptyMessage: 'No check-in data yet',
          ),
        ],
      ),
    );
  }
}

// --- Session Leaderboard ---

/// Resolves session color from sessionId — mirrors resolveSessionColor but takes id directly.
Color _sessionColorFromId(String sessionId) {
  return resolveSessionColor(Session(
    id: sessionId,
    title: sessionId,
    name: sessionId,
  ));
}

class _WallboardLeaderboard extends StatelessWidget {
  const _WallboardLeaderboard({
    required this.sessions,
    required this.totalCheckins,
    required this.mainCheckinSessionId,
  });

  final List<SessionCheckinStat> sessions;
  final int totalCheckins;
  final String mainCheckinSessionId;

  @override
  Widget build(BuildContext context) {
    final excludedMain = sessions
        .where((s) => s.sessionId != mainCheckinSessionId)
        .toList();
    final sorted = excludedMain
      ..sort((a, b) => b.checkInCount.compareTo(a.checkInCount));
    final maxCount = sorted.isNotEmpty
        ? (sorted.first.checkInCount.clamp(0, 0x7FFFFFFF))
        : 1;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: _wbCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Leaderboard',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: NlcColors.slate,
              ),
            ),
            const SizedBox(height: 24),
            if (sorted.isEmpty)
              Text(
                'No sessions yet',
                style: GoogleFonts.inter(color: NlcColors.mutedText, fontSize: 18),
              )
            else
              ...sorted.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                final count = s.checkInCount.clamp(0, 0x7FFFFFFF);
                final barPct = maxCount > 0 ? (count / maxCount) : 0.0;
                final sessionColor = _sessionColorFromId(s.sessionId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _WallboardLeaderboardRow(
                    rank: i + 1,
                    stat: s,
                    count: count,
                    barValue: barPct.clamp(0.0, 1.0),
                    sessionColor: sessionColor,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _WallboardLeaderboardRow extends StatelessWidget {
  const _WallboardLeaderboardRow({
    required this.rank,
    required this.stat,
    required this.count,
    required this.barValue,
    required this.sessionColor,
  });

  final int rank;
  final SessionCheckinStat stat;
  final int count;
  final double barValue;
  final Color sessionColor;

  @override
  Widget build(BuildContext context) {
    final isFull = stat.capacity > 0 && count >= stat.capacity;
    final remaining = stat.capacity > 0
        ? (stat.capacity - count).clamp(0, stat.capacity)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Color stripe (session wayfinding color)
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: sessionColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank + name + live chip + count
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$rank.',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: NlcColors.slate,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        stat.name,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: NlcColors.slate,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (stat.isActive) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: NlcColors.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: NlcColors.successGreen,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    Text(
                      NumberFormat.decimalPattern().format(count),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: sessionColor,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Stats pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (stat.preRegisteredCount > 0)
                      _WbPill(
                        label: '${stat.preRegisteredCount} pre-registered',
                        color: sessionColor,
                      ),
                    _WbPill(
                      label: '$count checked in',
                      color: NlcColors.successGreen,
                    ),
                    if (stat.capacity > 0)
                      _WbPill(
                        label: isFull
                            ? 'Full · ${stat.capacity} cap'
                            : '${stat.capacity} capacity · $remaining remaining',
                        color: isFull
                            ? const Color(0xFFEF4444)
                            : NlcColors.mutedText,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar in session color
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: barValue,
                    minHeight: 10,
                    backgroundColor: sessionColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(sessionColor),
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

class _WbPill extends StatelessWidget {
  const _WbPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

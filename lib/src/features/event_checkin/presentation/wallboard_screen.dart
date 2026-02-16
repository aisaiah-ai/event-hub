import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/analytics_aggregates.dart';
import '../../../services/checkin_analytics_service.dart';
import '../../../services/dashboard_layout_service.dart';
import '../../../widgets/rolling_counter.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';
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
          const CircularProgressIndicator(color: AppColors.gold),
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

// --- Theme ---

const Color _kWbGold = Color(0xFFD4A017);
const Color _kWbNavy = Color(0xFF1C3D5A);
const Color _kWbCardBg = Color(0xFFFAFAF9);

BoxDecoration _wbCardDecoration() => BoxDecoration(
      color: _kWbCardBg,
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

/// Wallboard metric tile: white, 16px radius, stronger shadow.
BoxDecoration _wbMetricTileDecoration() => BoxDecoration(
      color: Colors.white,
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
  final mainCheckinCount = sessions
      .where((s) => s.sessionId == mainCheckinId)
      .map((s) => s.checkInCount)
      .firstOrNull ?? 0;
  final totalExcludingMain = global.totalCheckins - mainCheckinCount;

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
              color: AppColors.statusCheckedIn
                  .withOpacity(0.6 + 0.4 * _controller.value),
              boxShadow: [
                BoxShadow(
                  color: AppColors.statusCheckedIn.withOpacity(0.6),
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
            color: AppColors.statusCheckedIn,
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
    final mainCheckinCount = mainCheckin?.checkInCount ?? 0;
    final sessionCheckins = global.totalCheckins - mainCheckinCount;

    final tiles = [
      _WallboardMetricTile(
        icon: Icons.people_rounded,
        label: 'Total Registrants',
        value: registrantCount,
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
                Icon(icon, size: 32, color: _kWbGold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kWbNavy,
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
              value: value,
              duration: const Duration(milliseconds: 2200),
              exaggerated: true,
              enableGlow: true,
              showDelta: true,
              style: GoogleFonts.inter(
                fontSize: 72,
                fontWeight: FontWeight.w800,
                color: _kWbNavy,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: _kWbGold.withOpacity(0.15),
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
                  color: Colors.black54,
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
              color: _kWbNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hourly Attendance Progress',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 380,
            child: _WallboardLineChart(hourlyCheckins: global.hourlyCheckins),
          ),
        ],
      ),
    );
  }
}

class _WallboardLineChart extends StatelessWidget {
  const _WallboardLineChart({required this.hourlyCheckins});

  final Map<String, int> hourlyCheckins;

  List<_WbChartPoint> _parsePoints() {
    final points = <_WbChartPoint>[];
    for (final e in hourlyCheckins.entries) {
      final key = e.key.trim();
      if (key.length < 10) continue;

      final dateStr = key.substring(0, 10);
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      int hour = 0;
      if (key.length >= 12) {
        final hourPart = key.substring(10).replaceAll(RegExp(r'[^0-9]'), '');
        hour = int.tryParse(hourPart) ?? 0;
      }

      points.add(_WbChartPoint(
        DateTime(date.year, date.month, date.day, hour.clamp(0, 23)),
        e.value,
      ));
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (hourlyCheckins.isEmpty) {
      return Center(
        child: Text(
          'No check-in data yet',
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 18),
        ),
      );
    }

    final points = _parsePoints();

    if (points.isEmpty) {
      return Center(
        child: Text(
          'No hourly data (format: YYYY-MM-DD-HH)',
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Ensure at least 2 points for line chart (add leading zero when single hour)
    List<_WbChartPoint> chartPoints = points.length >= 2
        ? points
        : [
            _WbChartPoint(
              points.first.time.subtract(const Duration(hours: 1)),
              0,
            ),
            ...points,
          ];
    chartPoints.sort((a, b) => a.time.compareTo(b.time));

    return _FlChartLineChart(points: chartPoints);
  }
}

class _WbChartPoint {
  _WbChartPoint(this.time, this.value);
  final DateTime time;
  final int value;
}

/// Line chart using fl_chart for reliable rendering across 1+ data points.
class _FlChartLineChart extends StatelessWidget {
  const _FlChartLineChart({required this.points});

  final List<_WbChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxVal = points
        .map((p) => p.value)
        .fold<double>(0, (a, b) => a > b ? a : b.toDouble())
        .clamp(1.0, double.infinity);
    // Earliest (index 0) at left, latest at right
    final n = points.length;
    final maxXVal = (n - 1).toDouble().clamp(0.0, double.infinity);
    final spots = [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), points[i].value.toDouble()),
    ];
    final timeFmt = DateFormat('h a');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXVal,
        minY: 0,
        maxY: maxVal,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.black26, width: 1),
            bottom: BorderSide(color: Colors.black26, width: 1),
            top: const BorderSide(color: Colors.transparent),
            right: const BorderSide(color: Colors.transparent),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxVal / 4,
              getTitlesWidget: (v, meta) => Text(
                v.toInt().toString(),
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i >= 0 && i < points.length) {
                  return Text(
                    timeFmt.format(points[i].time),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: _kWbGold,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: index == points.length - 1 ? 6 : 4,
                color: _kWbGold,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _kWbGold.withOpacity(0.12),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );
  }
}

// --- Session Leaderboard ---

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
    final maxCount = sorted.isNotEmpty ? sorted.first.checkInCount : 1;

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
              color: _kWbNavy,
            ),
          ),
          const SizedBox(height: 24),
          if (sorted.isEmpty)
            Text(
              'No sessions yet',
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 18),
            )
          else
            ...sorted.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final isTop = i == 0;
              final pct = maxCount > 0 ? (s.checkInCount / maxCount) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${i + 1}.',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _kWbNavy,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight:
                                        isTop ? FontWeight.w700 : FontWeight.w500,
                                    color: _kWbNavy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (s.isActive)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusCheckedIn
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'LIVE',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.statusCheckedIn,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Text(
                                NumberFormat.decimalPattern().format(s.checkInCount),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _kWbGold,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: _kWbGold.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isTop ? _kWbGold : _kWbGold.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

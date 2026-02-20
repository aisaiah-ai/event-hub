import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/nlc_theme.dart';
import '../../../core/theme/session_colors.dart';
import '../../../theme/nlc_palette.dart';
import '../../../models/analytics_aggregates.dart';
import '../../../models/session.dart';
import '../../../services/attendance_export_service.dart';
import '../../../services/checkin_analytics_service.dart';
import '../../../services/dashboard_layout_service.dart';
import '../../../widgets/rolling_counter.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'widgets/hourly_trend_chart.dart';
import 'widgets/last_updated_with_timezone.dart';

/// Real-time check-in analytics dashboard. Pure Session Architecture.
/// Reads ONLY from analytics/global and sessions/*/analytics/summary.
/// Executive light theme. Scalable for 3,000+ attendees.
class CheckinDashboardScreen extends StatefulWidget {
  const CheckinDashboardScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.eventVenue,
  });

  final String eventId;
  final String? eventTitle;
  final String? eventVenue;

  @override
  State<CheckinDashboardScreen> createState() => _CheckinDashboardScreenState();
}

class _CheckinDashboardScreenState extends State<CheckinDashboardScreen> {
  static const AggregationLevel _kDefaultExportLevel = AggregationLevel.entireEvent;
  bool _isExporting = false;
  bool _isEditLayout = false;
  List<String>? _localDashboardOrder;
  late final CheckinAnalyticsService _analyticsService;
  late final DashboardLayoutService _layoutService;
  late final Stream<GlobalAnalytics> _globalStream;
  late final Stream<List<SessionCheckinStat>> _sessionStream;
  late final Stream<({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  })> _first3Stream;
  late final Stream<List<String>> _layoutStream;

  String get _eventSlug => widget.eventId.replaceAll('-', '_');

  @override
  void initState() {
    super.initState();
    _analyticsService = CheckinAnalyticsService();
    _layoutService = DashboardLayoutService();
    _globalStream = _analyticsService.watchGlobalAnalytics(widget.eventId);
    _sessionStream = _analyticsService.watchSessionCheckins(widget.eventId);
    _first3Stream = _analyticsService.watchFirst3Data(widget.eventId);
    _layoutStream = _layoutService.watchDashboardOrder(widget.eventId);
  }

  Future<void> _onRefresh() async {
    _analyticsService.triggerRefresh();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final analyticsService = _analyticsService;
    final layoutService = _layoutService;
    final exportService = AttendanceExportService();

    return EventPageScaffold(
      event: null,
      eventSlug: widget.eventId.contains('nlc') ? 'nlc' : null,
      bodyMaxWidth: 1200,
      overlayOpacity: 0.65,
      appBar: null,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: StreamBuilder<GlobalAnalytics>(
          stream: _globalStream,
          builder: (context, snapshot) {
            final global = snapshot.data ?? const GlobalAnalytics();
            final lastUpdated = global.lastUpdated ?? DateTime.now();
            return StreamBuilder<List<SessionCheckinStat>>(
              stream: _sessionStream,
              builder: (context, sessSnap) {
                // Show loading only when we have no data (initial load). Keep content during refresh.
                if (!sessSnap.hasData && sessSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(64),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (sessSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load: ${sessSnap.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }
                final sessions = sessSnap.data ?? [];
                final registrantCount = global.totalRegistrants;
                return StreamBuilder<
                    ({
                      List<({String name, DateTime timestamp})> registrations,
                      List<({String name, DateTime timestamp})> checkins,
                    })>(
                  stream: _first3Stream,
                  builder: (context, first3Snap) {
                    final first3 = first3Snap.data ?? (
                      registrations: <({String name, DateTime timestamp})>[],
                      checkins: <({String name, DateTime timestamp})>[],
                    );
                    return StreamBuilder<List<String>>(
                      stream: _layoutStream,
                      initialData: kDefaultDashboardOrder,
                      builder: (context, orderSnap) {
                        final streamOrder = orderSnap.data ?? kDefaultDashboardOrder;
                        final order = _localDashboardOrder ?? streamOrder;
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _DashboardHeader(
                          eventId: widget.eventId,
                          eventTitle: widget.eventTitle ?? 'NLC Dashboard',
                          eventVenue: widget.eventVenue,
                          lastUpdated: lastUpdated,
                          isExporting: _isExporting,
                          isEditLayout: _isEditLayout,
                          onEditLayout: () => setState(() {
                            _isEditLayout = !_isEditLayout;
                            // Keep _localDashboardOrder after exit so layout persists when Firestore fails
                          }),
                          onExport: (type) => _runExport(
                            context,
                            type,
                            exportService,
                            analyticsService,
                          ),
                            ),
                            const SizedBox(height: 32),
                            _isEditLayout
                                ? _ReorderableDashboardSections(
                            order: order,
                            global: global,
                            sessions: sessions,
                            registrantCount: registrantCount,
                            first3: first3,
                            onReorder: (newOrder) {
                              setState(() => _localDashboardOrder = newOrder);
                              layoutService.saveDashboardOrder(
                                widget.eventId,
                                newOrder,
                              );
                            },
                                  )
                                : _DashboardSectionsInOrder(
                            order: order,
                            global: global,
                            sessions: sessions,
                            registrantCount: registrantCount,
                                    first3: first3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
        ),
      ),
    );
  }

  Future<void> _runExport(
    BuildContext context,
    String exportType,
    AttendanceExportService exportService,
    CheckinAnalyticsService analyticsService,
  ) async {
    setState(() => _isExporting = true);
    try {
      final summary = await analyticsService.getGlobalAnalytics(widget.eventId);
      final sessions = await analyticsService.fetchSessionStats(widget.eventId);
      bool ok = false;
      switch (exportType) {
        case 'raw':
          ok = await exportService.exportAndDownloadRaw(
            widget.eventId,
            eventSlug: _eventSlug,
          );
          break;
          case 'aggregated':
          ok = await exportService.exportAndDownloadAggregated(
            widget.eventId,
            sessionStats: sessions,
            global: summary,
            level: _kDefaultExportLevel,
            eventSlug: _eventSlug,
          );
          break;
        case 'excel':
          ok = await exportService.exportAndDownloadExcel(
            widget.eventId,
            sessionStats: sessions,
            global: summary,
            level: _kDefaultExportLevel,
            eventSlug: _eventSlug,
          );
          break;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Export started' : 'Export failed'),
            backgroundColor: ok ? NlcColors.successGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// --- Theme (NlcColors) ---

/// Refined card: ivory, 16px radius, subtle shadow.
BoxDecoration _lightCardDecoration() {
  return BoxDecoration(
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
}

/// Metric tile: ivory, 16px radius, stronger shadow for depth.
BoxDecoration _metricTileDecoration() {
  return BoxDecoration(
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
}

// --- Dashboard Header (inline, no app bar) ---

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.eventId,
    required this.eventTitle,
    this.eventVenue,
    required this.lastUpdated,
    required this.isExporting,
    required this.isEditLayout,
    required this.onEditLayout,
    required this.onExport,
  });

  final String eventId;
  final String eventTitle;
  final String? eventVenue;
  final DateTime lastUpdated;
  final bool isExporting;
  final bool isEditLayout;
  final VoidCallback onEditLayout;
  final void Function(String type) onExport;

  String get _conferenceTitle {
    if (eventTitle.isNotEmpty && eventTitle != 'Event') return eventTitle;
    if (eventId.contains('nlc')) return 'National Leaders Conference';
    return 'NLC Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            _conferenceTitle,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'NLC Dashboard',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const Spacer(),
            Text(
              'NLC DASHBOARD',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.95),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
        const _LiveIndicator(),
        const SizedBox(width: 16),
        LastUpdatedWithTimezone(
          lastUpdated: lastUpdated,
          fontSize: 13,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: () {
            final uri = Uri(
              path: '/admin/wallboard',
              queryParameters: {
                'eventId': eventId,
                if (eventTitle.isNotEmpty) 'eventTitle': eventTitle,
                if (eventVenue != null && eventVenue!.isNotEmpty) 'eventVenue': eventVenue!,
              },
            );
            context.go(uri.toString());
          },
          icon: const Icon(Icons.tv, size: 18),
          label: const Text('Wallboard Mode'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.more_vert, color: Colors.white.withOpacity(0.9)),
          tooltip: 'More options',
          onSelected: (value) {
            if (value == 'editLayout') {
              onEditLayout();
            } else {
              onExport(value);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'editLayout',
              child: Text(isEditLayout ? 'Done editing layout' : 'Edit layout'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'excel',
              child: Text('Export Summary (Excel)'),
            ),
            const PopupMenuItem(
              value: 'raw',
              child: Text('Export Raw Attendance (CSV)'),
            ),
            const PopupMenuItem(
              value: 'aggregated',
              child: Text('Export Aggregated (CSV)'),
            ),
          ],
        ),
      ],
    ),
      ],
    );
  }
}

Widget _buildDashboardSection(
  String sectionId,
  GlobalAnalytics global,
  List<SessionCheckinStat> sessions, {
  required int registrantCount,
  required ({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  }) first3,
}) {
  switch (sectionId) {
    case 'metrics':
      return _MetricsTiles(
        global: global,
        sessions: sessions,
        registrantCount: registrantCount,
      );
    case 'graph':
      return _DashboardTrendSection(global: global);
    case 'top5':
      return _Top5Row(global: global);
    case 'sessionLeaderboard':
      return _SessionLeaderboardSection(
        sessions: sessions,
        global: global,
        mainCheckinSessionId: 'main-checkin',
      );
    case 'first3':
      return _First3Section(first3: first3);
    default:
      return const SizedBox.shrink();
  }
}

class _DashboardSectionsInOrder extends StatelessWidget {
  const _DashboardSectionsInOrder({
    required this.order,
    required this.global,
    required this.sessions,
    required this.registrantCount,
    required this.first3,
  });

  final List<String> order;
  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final int registrantCount;
  final ({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  }) first3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in order) ...[
          _buildDashboardSection(id, global, sessions, registrantCount: registrantCount, first3: first3),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _ReorderableDashboardSections extends StatelessWidget {
  const _ReorderableDashboardSections({
    required this.order,
    required this.global,
    required this.sessions,
    required this.registrantCount,
    required this.first3,
    required this.onReorder,
  });

  final List<String> order;
  final GlobalAnalytics global;
  final List<SessionCheckinStat> sessions;
  final int registrantCount;
  final ({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  }) first3;
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
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: ReorderableDragStartListener(
                    index: i,
                    child: Icon(
                      Icons.drag_handle,
                      color: NlcColors.mutedText,
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDashboardSection(
                    order[i],
                    global,
                    sessions,
                    registrantCount: registrantCount,
                    first3: first3,
                  ),
                ),
              ],
            ),
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
          builder: (context, _) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NlcColors.successGreen.withOpacity(
                  0.6 + 0.4 * _controller.value,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NlcColors.successGreen.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NlcColors.successGreen,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// --- Metric Tiles (3 equal) ---

class _MetricsTiles extends StatelessWidget {
  const _MetricsTiles({
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
    // Sum breakout sessions only (avoids negative when global.totalCheckins is stale)
    final sessionCheckins = sessions
        .where((s) => s.sessionId != mainCheckinId)
        .fold<int>(0, (sum, s) => sum + (s.checkInCount.clamp(0, 0x7FFFFFFF)));

    final registrantDisplay = registrantCount.clamp(0, 0x7FFFFFFF);
    final tiles = [
      _MetricTile(
        icon: Icons.people_rounded,
        label: 'Total Registrants',
        value: registrantDisplay,
        subtext: null,
        showDashWhenZero: true,
      ),
      _MetricTile(
        icon: Icons.check_circle_rounded,
        label: 'Main Check-In Total',
        value: mainCheckinCount,
        subtext: 'Main Conference Entry',
        showDashWhenZero: false,
      ),
      _MetricTile(
        icon: Icons.bar_chart_rounded,
        label: 'Session Check-Ins',
        value: sessionCheckins,
        subtext: 'Breakout Sessions Only',
        showDashWhenZero: false,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtext,
    this.showDashWhenZero = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final String? subtext;
  final bool showDashWhenZero;

  @override
  Widget build(BuildContext context) {
    final showDash = showDashWhenZero && value == 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _metricTileDecoration(),
      child: SizedBox(
        height: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: NlcPalette.brandBlue),
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
              color: NlcPalette.brandBlue.withValues(alpha: 0.35),
            ),
            if (showDash)
              Text(
                '—',
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: NlcColors.slate,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            else
              RollingCounter(
                value: value.clamp(0, 0x7FFFFFFF),
                duration: const Duration(milliseconds: 1800),
                exaggerated: true,
                enableGlow: false,
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: NlcColors.slate,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: GoogleFonts.inter(fontSize: 14, color: NlcColors.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// First 3 Registrations + First 3 Check-Ins (side by side).
class _First3Section extends StatelessWidget {
  const _First3Section({
    required this.first3,
  });

  final ({
    List<({String name, DateTime timestamp})> registrations,
    List<({String name, DateTime timestamp})> checkins,
  }) first3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _First3RegistrationsCard(items: first3.registrations)),
                  const SizedBox(width: 24),
                  Expanded(child: _First3CheckinsCard(items: first3.checkins)),
                ],
              )
            : Column(
                children: [
                  _First3RegistrationsCard(items: first3.registrations),
                  const SizedBox(height: 24),
                  _First3CheckinsCard(items: first3.checkins),
                ],
              );
      },
    );
  }
}

class _First3RegistrationsCard extends StatelessWidget {
  const _First3RegistrationsCard({
    required this.items,
  });

  final List<({String name, DateTime timestamp})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 20, color: NlcPalette.brandBlue),
              const SizedBox(width: 8),
              Text(
                'First 3 Registrations',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NlcColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(3, (i) {
            if (i >= items.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '—',
                  style: GoogleFonts.inter(fontSize: 15, color: NlcColors.mutedText),
                ),
              );
            }
            final r = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${i + 1}.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NlcColors.slate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.name,
                      style: GoogleFonts.inter(fontSize: 15, color: NlcColors.slate),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ' — ${DateFormat.MMMd().add_jm().format(r.timestamp)}',
                    style: GoogleFonts.inter(fontSize: 13, color: NlcColors.mutedText),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _First3CheckinsCard extends StatelessWidget {
  const _First3CheckinsCard({
    required this.items,
  });

  final List<({String name, DateTime timestamp})> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 20, color: NlcPalette.brandBlue),
              const SizedBox(width: 8),
              Text(
                'First 3 Check-Ins',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: NlcColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(3, (i) {
            if (i >= items.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '—',
                  style: GoogleFonts.inter(fontSize: 15, color: NlcColors.mutedText),
                ),
              );
            }
            final c = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    '${i + 1}.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NlcColors.slate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: GoogleFonts.inter(fontSize: 15, color: NlcColors.slate),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ' — ${DateFormat.MMMd().add_jm().format(c.timestamp)}',
                    style: GoogleFonts.inter(fontSize: 13, color: NlcColors.mutedText),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


// --- Top 5 Row ---

class _DashboardTrendSection extends StatelessWidget {
  const _DashboardTrendSection({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _lightCardDecoration(),
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
            height: 320,
            lineColor: NlcPalette.brandBlue,
            emptyMessage: 'No check-in data yet',
          ),
        ],
      ),
    );
  }
}

class _Top5Row extends StatelessWidget {
  const _Top5Row({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Top5Card(
                      title: 'Top 5 Regions',
                      data: global.regionCounts,
                      total: global.totalCheckins,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _Top5Card(
                      title: 'Top 5 Ministries',
                      data: global.ministryCounts,
                      total: global.totalCheckins,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _Top5Card(
                    title: 'Top 5 Regions',
                    data: global.regionCounts,
                    total: global.totalCheckins,
                  ),
                  const SizedBox(height: 24),
                  _Top5Card(
                    title: 'Top 5 Ministries',
                    data: global.ministryCounts,
                    total: global.totalCheckins,
                  ),
                ],
              );
      },
    );
  }
}

class _Top5Card extends StatelessWidget {
  const _Top5Card({
    required this.title,
    required this.data,
    required this.total,
  });

  final String title;
  final Map<String, int> data;
  final int total;

  static int _nonNegative(int v) => v.clamp(0, 0x7FFFFFFF);

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()
      ..sort((a, b) => _nonNegative(b.value).compareTo(_nonNegative(a.value)));
    final top5 = sorted.take(5).toList();
    final maxVal = top5.isNotEmpty ? _nonNegative(top5.first.value) : 1;
    // Use sum of this card's data so % never exceeds 100% (avoids 394% when totalCheckins is out of sync)
    final sumOfData = data.values.fold<int>(0, (a, b) => a + _nonNegative(b));

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: NlcColors.slate,
            ),
          ),
          const SizedBox(height: 24),
          if (top5.isEmpty)
            Text(
              'No data yet',
              style: GoogleFonts.inter(color: NlcColors.mutedText, fontSize: 14),
            )
          else
            ...top5.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              final val = _nonNegative(entry.value);
              final pct = maxVal > 0 ? (val / maxVal) : 0.0;
              final pctNum = sumOfData > 0 ? (val / sumOfData * 100) : 0.0;
              final pctTotal = sumOfData > 0
                  ? (val / sumOfData * 100).toStringAsFixed(0)
                  : '0';
              // Only show bar when displayed % is non-zero (avoids bar at "0%")
              final showBar = val > 0 && pctNum >= 0.5;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: NlcColors.slate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$pctTotal%',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NlcColors.mutedText,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showBar)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: NlcColors.secondaryBlue.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(NlcColors.secondaryBlue),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  if (idx < top5.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: Divider(
                        height: 1,
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// --- Session Leaderboard ---

class _SessionLeaderboardSection extends StatelessWidget {
  const _SessionLeaderboardSection({
    required this.sessions,
    required this.global,
    required this.mainCheckinSessionId,
  });

  final List<SessionCheckinStat> sessions;
  final GlobalAnalytics global;
  final String mainCheckinSessionId;

  @override
  Widget build(BuildContext context) {
    final excludedMain = sessions
        .where((s) => s.sessionId != mainCheckinSessionId)
        .toList();
    final sorted = excludedMain
      ..sort((a, b) => b.checkInCount.compareTo(a.checkInCount));
    final total = excludedMain.fold<int>(0, (sum, s) => sum + (s.checkInCount.clamp(0, 0x7FFFFFFF)));
    final maxCount = sorted.isNotEmpty ? (sorted.first.checkInCount.clamp(0, 0x7FFFFFFF)) : 1;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: _lightCardDecoration(),
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
              style: GoogleFonts.inter(color: NlcColors.mutedText, fontSize: 14),
            )
          else
            ...sorted.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final isTop = i == 0;
              final count = s.checkInCount.clamp(0, 0x7FFFFFFF);
              final pct = total > 0 ? (count / total) * 100 : 0.0;
              final barPct = maxCount > 0 ? (count / maxCount) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SessionLeaderboardRow(
                  rank: i + 1,
                  sessionId: s.sessionId,
                  sessionName: s.name,
                  count: count,
                  percent: pct,
                  barValue: barPct.clamp(0.0, 1.0),
                  isTop: isTop,
                  isActive: s.isActive,
                  capacity: s.capacity,
                  preRegisteredCount: s.preRegisteredCount,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SessionLeaderboardRow extends StatefulWidget {
  const _SessionLeaderboardRow({
    required this.rank,
    required this.sessionId,
    required this.sessionName,
    required this.count,
    required this.percent,
    required this.barValue,
    required this.isTop,
    this.isActive = false,
    this.capacity = 0,
    this.preRegisteredCount = 0,
  });

  final int rank;
  final String sessionId;
  final String sessionName;
  final int count;
  final double percent;
  final double barValue;
  final bool isTop;
  final bool isActive;
  final int capacity;
  final int preRegisteredCount;

  @override
  State<_SessionLeaderboardRow> createState() => _SessionLeaderboardRowState();
}

class _SessionLeaderboardRowState extends State<_SessionLeaderboardRow> {
  bool _hover = false;

  Color get _sessionColor => resolveSessionColor(
        Session(id: widget.sessionId, title: widget.sessionName, name: widget.sessionName),
      );

  @override
  Widget build(BuildContext context) {
    final sessionColor = _sessionColor;
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(_hover ? 8 : 4),
        decoration: BoxDecoration(
          color: _hover ? sessionColor.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${widget.rank}.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: NlcColors.slate,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.sessionName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: NlcColors.slate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NlcColors.successGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: NlcColors.successGreen,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 56,
                  child: Text(
                    NumberFormat.decimalPattern().format(widget.count.clamp(0, 0x7FFFFFFF)),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sessionColor,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${widget.percent.clamp(0.0, 100.0).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: NlcColors.mutedText,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildStatsPills(sessionColor),
            const SizedBox(height: 6),
            if (widget.count > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.barValue.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: sessionColor.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(sessionColor),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPills(Color sessionColor) {
    final pills = <({String label, Color bg, Color fg})>[];

    if (widget.preRegisteredCount > 0) {
      pills.add((
        label: '${widget.preRegisteredCount} pre-registered',
        bg: sessionColor.withValues(alpha: 0.10),
        fg: sessionColor,
      ));
    }
    pills.add((
      label: '${widget.count} checked in',
      bg: NlcColors.successGreen.withValues(alpha: 0.12),
      fg: NlcColors.successGreen,
    ));
    if (widget.capacity > 0) {
      final remaining = (widget.capacity - widget.count).clamp(0, widget.capacity);
      final isFull = remaining == 0;
      pills.add((
        label: isFull ? 'Full · ${widget.capacity} cap' : '${widget.capacity} capacity · $remaining remaining',
        bg: isFull
            ? const Color(0xFFEF4444).withValues(alpha: 0.10)
            : NlcColors.mutedText.withValues(alpha: 0.10),
        fg: isFull ? const Color(0xFFEF4444) : NlcColors.mutedText,
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: pills.map((p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          p.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: p.fg,
          ),
        ),
      )).toList(),
    );
  }
}

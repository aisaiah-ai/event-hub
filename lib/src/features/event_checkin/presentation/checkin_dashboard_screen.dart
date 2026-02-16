import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/analytics_aggregates.dart';
import '../../../services/attendance_export_service.dart';
import '../../../services/checkin_analytics_service.dart';
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';

/// Real-time check-in analytics dashboard. Pure Session Architecture.
/// Reads ONLY from analytics/global and sessions/*/analytics/summary.
/// No attendance collection scans. Scalable for 3,000+ attendees.
class CheckinDashboardScreen extends StatefulWidget {
  const CheckinDashboardScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  final String eventId;
  final String? eventTitle;

  @override
  State<CheckinDashboardScreen> createState() => _CheckinDashboardScreenState();
}

class _CheckinDashboardScreenState extends State<CheckinDashboardScreen> {
  AggregationLevel _aggregationLevel = AggregationLevel.perSession;
  bool _isExporting = false;

  String get _eventSlug => widget.eventId.replaceAll('-', '_');

  @override
  Widget build(BuildContext context) {
    final analyticsService = CheckinAnalyticsService();
    final exportService = AttendanceExportService();

    return EventPageScaffold(
      event: null,
      eventSlug: widget.eventId.contains('nlc') ? 'nlc' : null,
      appBar: AppBar(
        title: Text(widget.eventTitle ?? 'Check-In Dashboard'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: metrics + controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StreamBuilder<GlobalAnalytics>(
                      stream: analyticsService.watchGlobalAnalytics(widget.eventId),
                      builder: (context, snapshot) {
                        debugPrint('[Dashboard] GlobalAnalytics: connectionState=${snapshot.connectionState} hasError=${snapshot.hasError} error=${snapshot.error}');
                        final global = snapshot.data ?? const GlobalAnalytics();
                        debugPrint('[Dashboard] GlobalAnalytics: totalCheckins=${global.totalCheckins} unique=${global.totalUniqueAttendees}');
                        return _MetricsCards(global: global);
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right: aggregation + export
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AggregationDropdown(
                        value: _aggregationLevel,
                        onChanged: (v) =>
                            setState(() => _aggregationLevel = v),
                      ),
                      const SizedBox(height: 12),
                      _ExportButton(
                        isExporting: _isExporting,
                        onExport: (type) => _runExport(
                          context,
                          type,
                          exportService,
                          analyticsService,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Session table
              StreamBuilder<List<SessionCheckinStat>>(
                stream: analyticsService.watchSessionCheckins(widget.eventId),
                builder: (context, snapshot) {
                  debugPrint('[Dashboard] SessionCheckins: connectionState=${snapshot.connectionState} hasError=${snapshot.hasError} error=${snapshot.error} eventId=${widget.eventId}');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    debugPrint('[Dashboard] SessionCheckins ERROR: ${snapshot.error}');
                    return Text(
                      'Failed to load session analytics: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red.shade400),
                    );
                  }
                  final sessions = snapshot.data ?? const [];
                  debugPrint('[Dashboard] SessionCheckins: ${sessions.length} sessions, counts=${sessions.map((s) => '${s.sessionId}:${s.checkInCount}').toList()}');
                  return StreamBuilder<GlobalAnalytics>(
                    stream: analyticsService.watchGlobalAnalytics(widget.eventId),
                    builder: (context, sumSnap) {
                      final global = sumSnap.data ?? const GlobalAnalytics();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Top5AndTimeline(global: global),
                          const SizedBox(height: 24),
                          _SessionTable(
                            sessions: sessions,
                            aggregationLevel: _aggregationLevel,
                            totalCheckins: global.totalCheckins,
                            hourlyCheckins: global.hourlyCheckins,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runExport(
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
            level: _aggregationLevel,
            eventSlug: _eventSlug,
          );
          break;
        case 'excel':
          ok = await exportService.exportAndDownloadExcel(
            widget.eventId,
            sessionStats: sessions,
            global: summary,
            level: _aggregationLevel,
            eventSlug: _eventSlug,
          );
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(ok ? 'Export started' : 'Export failed (check console)'),
            backgroundColor: ok ? AppColors.statusCheckedIn : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _MetricsCards extends StatelessWidget {
  const _MetricsCards({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Total Unique Attendees',
            value: '${global.totalUniqueAttendees}',
            icon: Icons.people_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Total Check-Ins',
            value: '${global.totalCheckins}',
            icon: Icons.check_circle_rounded,
            accent: AppColors.statusCheckedIn,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.goldGradientEnd;
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Top5AndTimeline extends StatelessWidget {
  const _Top5AndTimeline({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Top5Card(
            title: 'Top 5 Regions',
            entries: global.top5Regions,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Top5Card(
            title: 'Top 5 Ministries',
            entries: global.top5Ministries,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TimelineCard(global: global),
        ),
      ],
    );
  }
}

class _Top5Card extends StatelessWidget {
  const _Top5Card({
    required this.title,
    required this.entries,
  });

  final String title;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(
                'No data yet',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary87.withValues(alpha: 0.6),
                ),
              )
            else
              ...entries.asMap().entries.map((e) {
                final i = e.key;
                final entry = e.value;
                final maxCount = entries.isNotEmpty
                    ? entries.map((x) => x.value).reduce((a, b) => a > b ? a : b)
                    : 1;
                final pct = maxCount > 0 ? (entry.value / maxCount) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.goldGradientEnd.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldGradientEnd,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            width: constraints.maxWidth * pct.clamp(0.0, 1.0),
                            height: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.goldGradientEnd.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.global});

  final GlobalAnalytics global;

  @override
  Widget build(BuildContext context) {
    final earliestCheckin = global.earliestCheckin;
    final earliestReg = global.earliestRegistration;
    final peakKey = global.peakHourKey;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline Intelligence',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            _TimelineRow(
              label: 'Earliest Check-in',
              value: earliestCheckin != null && earliestCheckin.registrantId.isNotEmpty
                  ? DateFormat.yMd().add_jm().format(earliestCheckin.timestamp)
                  : '—',
            ),
            _TimelineRow(
              label: 'Earliest Registration',
              value: earliestReg != null && earliestReg.registrantId.isNotEmpty
                  ? DateFormat.yMd().add_jm().format(earliestReg.timestamp)
                  : '—',
            ),
            _TimelineRow(
              label: 'Peak Hour',
              value: peakKey != null ? _formatPeakKey(peakKey) : '—',
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeakKey(String key) {
    if (key.length >= 13) {
      final date = key.substring(0, 10);
      final hour = key.length > 11 ? key.substring(11) : '';
      return '$date ${hour.padLeft(2, '0')}:00';
    }
    return key;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AggregationDropdown extends StatelessWidget {
  const _AggregationDropdown({
    required this.value,
    required this.onChanged,
  });

  final AggregationLevel value;
  final void Function(AggregationLevel) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<AggregationLevel>(
        value: value,
        decoration: InputDecoration(
          labelText: 'Aggregation',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: const [
          DropdownMenuItem(
              value: AggregationLevel.perSession,
              child: Text('Per Session')),
          DropdownMenuItem(
              value: AggregationLevel.perDay,
              child: Text('Per Day')),
          DropdownMenuItem(
              value: AggregationLevel.entireEvent,
              child: Text('Entire Event')),
          DropdownMenuItem(
              value: AggregationLevel.custom,
              child: Text('Custom')),
        ],
        onChanged: (v) => onChanged(v ?? AggregationLevel.perSession),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.isExporting,
    required this.onExport,
  });

  final bool isExporting;
  final void Function(String type) onExport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Export',
      onSelected: (v) {
        // ignore: unnecessary_null_comparison
        if (v != null) onExport(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.goldGradientEnd,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isExporting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.download_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Export',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'raw', child: Text('All Attendance (Raw)')),
        const PopupMenuItem(
            value: 'aggregated', child: Text('Aggregated Report')),
        const PopupMenuItem(value: 'excel', child: Text('Excel (Both)')),
      ],
    );
  }
}

class _SessionTable extends StatelessWidget {
  const _SessionTable({
    required this.sessions,
    required this.aggregationLevel,
    required this.totalCheckins,
    this.hourlyCheckins = const {},
  });

  final List<SessionCheckinStat> sessions;
  final AggregationLevel aggregationLevel;
  final int totalCheckins;
  final Map<String, int> hourlyCheckins;

  @override
  Widget build(BuildContext context) {
    if (aggregationLevel == AggregationLevel.entireEvent) {
      return const SizedBox.shrink();
    }

    List<_TableRow> rows;
    if (aggregationLevel == AggregationLevel.perDay) {
      if (hourlyCheckins.isNotEmpty) {
        final byDay = <String, int>{};
        for (final e in hourlyCheckins.entries) {
          final dateKey = e.key.length >= 10 ? e.key.substring(0, 10) : e.key;
          byDay[dateKey] = (byDay[dateKey] ?? 0) + e.value;
        }
        final sortedDays = byDay.keys.toList()..sort();
        rows = sortedDays
            .map((day) {
              final dayTotal = byDay[day]!;
              final pct = totalCheckins > 0 ? (dayTotal / totalCheckins) * 100 : 0.0;
              return _TableRow(session: day, attendance: dayTotal, percentOfTotal: pct);
            })
            .toList();
      } else {
        final byDay = <String, List<SessionCheckinStat>>{};
        for (final s in sessions) {
          final key = s.startAt != null
              ? DateFormat('yyyy-MM-dd').format(s.startAt!)
              : 'Unknown';
          byDay.putIfAbsent(key, () => []).add(s);
        }
        final sortedDays = byDay.keys.toList()..sort();
        rows = sortedDays
            .map((day) {
              final sess = byDay[day]!;
              final dayTotal = sess.fold<int>(0, (a, x) => a + x.checkInCount);
              final pct = totalCheckins > 0 ? (dayTotal / totalCheckins) * 100 : 0.0;
              return _TableRow(session: day, attendance: dayTotal, percentOfTotal: pct);
            })
            .toList();
      }
    } else {
      rows = sessions
          .map((s) {
            final pct = totalCheckins > 0
                ? (s.checkInCount / totalCheckins) * 100
                : 0.0;
            return _TableRow(
              session: s.name,
              attendance: s.checkInCount,
              percentOfTotal: pct,
            );
          })
          .toList();
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Session Attendance',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No sessions found.',
                style: GoogleFonts.inter(color: AppColors.textPrimary87),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: AppColors.goldGradientEnd.withValues(alpha: 0.15),
                  ),
                  children: [
                    _TableHeader('Session'),
                    _TableHeader('Attendance'),
                    _TableHeader('% of Total'),
                  ],
                ),
                ...rows.map(
                  (r) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          r.session,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${r.attendance}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: AppColors.goldGradientEnd,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${r.percentOfTotal.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableRow {
  const _TableRow({
    required this.session,
    required this.attendance,
    required this.percentOfTotal,
  });
  final String session;
  final int attendance;
  final double percentOfTotal;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

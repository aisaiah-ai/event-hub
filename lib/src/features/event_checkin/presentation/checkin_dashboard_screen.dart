import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/event_stats.dart';
import '../../../services/checkin_analytics_service.dart';
import '../../../services/event_stats_service.dart' show EventStatsService, CheckinBucket;
import '../../events/widgets/event_page_scaffold.dart';
import 'theme/checkin_theme.dart';

/// Real-time check-in analytics dashboard. Streams events/{eventId}/stats/overview.
/// Shows skeleton/zeroes when stats doc missing (no crash).
class CheckinDashboardScreen extends StatelessWidget {
  const CheckinDashboardScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.statsService,
  });

  final String eventId;
  final String? eventTitle;
  final EventStatsService? statsService;

  @override
  Widget build(BuildContext context) {
    final analyticsService = CheckinAnalyticsService();

    return EventPageScaffold(
      event: null,
      eventSlug: eventId.contains('nlc') ? 'nlc' : null,
      appBar: AppBar(
        title: Text(eventTitle ?? 'Check-In Dashboard'),
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<AnalyticsSummary>(
                stream: analyticsService.watchSummary(eventId),
                builder: (context, snapshot) {
                  final summary =
                      snapshot.data ??
                      const AnalyticsSummary(totalCheckIns: 0, lastUpdated: null);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.query_stats_rounded),
                      title: const Text('Total Check-Ins'),
                      subtitle: Text(
                        summary.lastUpdated == null
                            ? 'No updates yet'
                            : 'Updated ${DateFormat.yMd().add_jm().format(summary.lastUpdated!)}',
                      ),
                      trailing: Text(
                        '${summary.totalCheckIns}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Session Check-Ins',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<SessionCheckinStat>>(
                stream: analyticsService.watchSessionCheckins(eventId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Failed to load session analytics: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red.shade400),
                    );
                  }
                  final sessions = snapshot.data ?? const <SessionCheckinStat>[];
                  if (sessions.isEmpty) {
                    return Text(
                      'No sessions found for this event.',
                      style: GoogleFonts.inter(color: AppColors.textPrimary87),
                    );
                  }
                  return Column(
                    children: sessions
                        .map(
                          (s) => Card(
                            child: ListTile(
                              title: Text(s.name),
                              subtitle: Text(s.sessionId),
                              trailing: Text(
                                '${s.checkInCount}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: AppColors.goldGradientEnd,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _KpiCard(
              label: 'Total Registered',
              value: '${stats.totalRegistrations}',
              icon: Icons.how_to_reg_rounded,
            ),
            _KpiCard(
              label: 'Checked In',
              value: '${stats.totalCheckedIn}',
              subtitle: '${stats.checkInPercent.toStringAsFixed(1)}%',
              icon: Icons.check_circle_rounded,
              accent: AppColors.statusCheckedIn,
            ),
            _KpiCard(
              label: 'Early Bird',
              value: '${stats.earlyBirdCount}',
              subtitle: stats.firstEarlyBirdRegisteredAt != null
                  ? 'First: ${DateFormat.Md().format(stats.firstEarlyBirdRegisteredAt!)}'
                  : '${stats.earlyBirdPercent.toStringAsFixed(1)}%',
              icon: Icons.schedule_rounded,
            ),
            _KpiCard(
              label: 'First Check-In',
              value: stats.firstCheckInAt != null
                  ? DateFormat.jm().format(stats.firstCheckInAt!)
                  : '—',
              icon: Icons.flag_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.goldGradientEnd;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textPrimary87.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Top5Section extends StatelessWidget {
  const _Top5Section({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Analytics',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Top5Card(title: 'Regions', entries: stats.top5Regions),
                _Top5Card(title: 'Ministries', entries: stats.top5Ministries),
                _Top5Card(title: 'Services', entries: stats.top5Services),
                if (stats.top5RegionOtherText.isNotEmpty)
                  _Top5Card(
                    title: 'Region Other Text',
                    entries: stats.top5RegionOtherText,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Top5Card extends StatelessWidget {
  const _Top5Card({required this.title, required this.entries});

  final String title;
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 220,
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
              const SizedBox(height: 16),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
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
                        const SizedBox(width: 12),
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
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTotalsSection extends StatelessWidget {
  const _SessionTotalsSection({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Attendance',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            if (stats.sessionTotals.isEmpty)
              Text(
                'No session data yet',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary87.withValues(alpha: 0.6),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: stats.sessionTotals.entries.map((e) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.goldGradientEnd.withValues(alpha: 0.3),
                      child: Text(
                        '${e.value}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    label: Text(e.key),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _FirstSessionCheckInSection extends StatelessWidget {
  const _FirstSessionCheckInSection({required this.stats});

  final EventStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.firstSessionCheckIn.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Session Check-Ins',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats.firstSessionCheckIn.entries.map((e) {
                final v = e.value;
                final time = v.at != null ? DateFormat.jm().format(v.at!) : '—';
                return Chip(
                  avatar: const Icon(Icons.flag_rounded, size: 18, color: AppColors.goldGradientEnd),
                  label: Text('${e.key}: $time'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInRateSparkline extends StatelessWidget {
  const _CheckInRateSparkline({
    required this.eventId,
    required this.statsService,
  });

  final String eventId;
  final EventStatsService statsService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CheckinBucket>>(
      stream: statsService.watchCheckinBuckets(eventId, limit: 60),
      builder: (context, snapshot) {
        final buckets = snapshot.data ?? [];
        final reversed = buckets.reversed.toList();

        return Card(
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check-In Rate (last 60 min)',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 16),
                if (reversed.isEmpty)
                  Text(
                    'No check-in data yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary87.withValues(alpha: 0.6),
                    ),
                  )
                else
                  SizedBox(
                    height: 80,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: reversed.map((b) {
                        final maxCount = buckets.map((x) => x.count).fold(0, (a, c) => a > c ? a : c);
                        final h = maxCount > 0 ? (b.count / maxCount) * 60 : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Tooltip(
                              message: '${b.bucketId}: ${b.count}',
                              child: Container(
                                height: h.clamp(4.0, 60.0),
                                decoration: BoxDecoration(
                                  color: AppColors.goldGradientEnd.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

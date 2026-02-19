import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/nlc_theme.dart';
import '../../../../theme/nlc_palette.dart';
import 'package:intl/intl.dart';

/// Shared line chart for check-in trend (keys: YYYY-MM-DD-HH-mm, 15-minute buckets).
/// Also accepts legacy YYYY-MM-DD-HH. Used by dashboard and wallboard.
class HourlyTrendChart extends StatelessWidget {
  const HourlyTrendChart({
    super.key,
    required this.hourlyCheckins,
    this.height = 320,
    this.lineColor,
    this.emptyMessage = 'No check-in data yet',
  });

  final Map<String, int> hourlyCheckins;
  final double height;
  final Color? lineColor;
  final String emptyMessage;

  /// Parse Firestore keys (YYYY-MM-DD-HH-mm for 15-min, or legacy YYYY-MM-DD-HH) into sorted chart points.
  static List<({DateTime time, int value})> parseHourlyPoints(Map<String, int> hourlyCheckins) {
    final points = <({DateTime time, int value})>[];
    for (final e in hourlyCheckins.entries) {
      final key = e.key.trim();
      if (key.length < 10) continue;
      final dateStr = key.substring(0, 10);
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final parts = key.split(RegExp(r'[-_\s]'));
      int hour = 0;
      int minute = 0;
      if (parts.length >= 4) {
        hour = int.tryParse(parts[3]) ?? 0;
        if (parts.length >= 5) {
          minute = int.tryParse(parts[4]) ?? 0;
        }
      }
      points.add((
        time: DateTime(date.year, date.month, date.day, hour.clamp(0, 23), minute.clamp(0, 59)),
        value: (e.value).clamp(0, 0x7FFFFFFF),
      ));
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (hourlyCheckins.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyMessage,
            style: GoogleFonts.inter(color: NlcColors.mutedText, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final points = parseHourlyPoints(hourlyCheckins);
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No trend data (expected keys: YYYY-MM-DD-HH-mm)',
            style: GoogleFonts.inter(color: NlcColors.mutedText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    List<({DateTime time, int value})> chartPoints = points.length >= 2
        ? points
        : [
            (time: points.first.time.subtract(const Duration(hours: 1)), value: 0),
            ...points,
          ];
    chartPoints.sort((a, b) => a.time.compareTo(b.time));

    final color = lineColor ?? NlcPalette.brandBlue;
    return SizedBox(
      height: height,
      child: _LineChartPainter(
        points: chartPoints,
        lineColor: color,
      ),
    );
  }
}

class _LineChartPainter extends StatelessWidget {
  const _LineChartPainter({
    required this.points,
    required this.lineColor,
  });

  final List<({DateTime time, int value})> points;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final maxVal = points
        .map((p) => p.value.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final n = points.length;
    final maxXVal = (n - 1).toDouble().clamp(0.0, double.infinity);
    final spots = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), points[i].value.toDouble()),
    ];
    final timeFmt = DateFormat('h:mm a');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXVal,
        minY: 0,
        maxY: maxVal,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) => FlLine(
            color: NlcColors.secondaryBlue.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (v) => FlLine(
            color: NlcColors.secondaryBlue.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: NlcColors.mutedText.withValues(alpha: 0.4), width: 1),
            bottom: BorderSide(color: NlcColors.mutedText.withValues(alpha: 0.4), width: 1),
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
                style: TextStyle(color: NlcColors.mutedText, fontSize: 12),
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
                    style: TextStyle(color: NlcColors.mutedText, fontSize: 12),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: index == points.length - 1 ? 6 : 4,
                color: lineColor,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 200),
    );
  }
}

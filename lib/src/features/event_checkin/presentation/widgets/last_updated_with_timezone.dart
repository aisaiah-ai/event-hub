import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Timezone option for Last Updated display.
class _TzOption {
  const _TzOption(this.id, this.label, this.locationName);

  final String id;
  final String label;
  final String locationName;
}

const _kDefaultTzId = 'America/Los_Angeles';
const _kPrefsKey = 'last_updated_timezone';

const _kOptions = [
  _TzOption('America/Los_Angeles', 'Pacific (PST/PDT)', 'America/Los_Angeles'),
  _TzOption('America/Denver', 'Mountain (MST/MDT)', 'America/Denver'),
  _TzOption('America/Chicago', 'Central (CST/CDT)', 'America/Chicago'),
  _TzOption('America/New_York', 'Eastern (EST/EDT)', 'America/New_York'),
  _TzOption('UTC', 'UTC', 'UTC'),
];

bool _tzInitialized = false;

void _ensureTzInitialized() {
  if (!_tzInitialized) {
    try {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    } catch (_) {}
  }
}

/// Formats [dateTime] in [locationName] with timezone abbreviation.
String _formatWithTz(DateTime dateTime, String locationName) {
  _ensureTzInitialized();
  if (!_tzInitialized) {
    return DateFormat.jms().format(dateTime);
  }
  try {
    final loc = locationName == 'UTC'
        ? tz.UTC
        : tz.getLocation(locationName);
    final tzDt = tz.TZDateTime.from(dateTime, loc);
    final tzInfo = loc.timeZone(tzDt.millisecondsSinceEpoch);
    final abbrev = tzInfo.abbreviation;
    return '${DateFormat.jms().format(tzDt)} $abbrev';
  } catch (_) {
    return DateFormat.jms().format(dateTime);
  }
}

/// Last Updated timestamp with timezone. Defaults to PST.
/// Tap to change timezone; selection persisted.
class LastUpdatedWithTimezone extends StatefulWidget {
  const LastUpdatedWithTimezone({
    super.key,
    required this.lastUpdated,
    this.fontSize = 13,
    this.color,
  });

  final DateTime lastUpdated;
  final double fontSize;
  final Color? color;

  @override
  State<LastUpdatedWithTimezone> createState() =>
      _LastUpdatedWithTimezoneState();
}

class _LastUpdatedWithTimezoneState extends State<LastUpdatedWithTimezone> {
  String _tzId = _kDefaultTzId;

  @override
  void initState() {
    super.initState();
    _loadTz();
  }

  Future<void> _loadTz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kPrefsKey);
      if (saved != null &&
          _kOptions.any((o) => o.id == saved)) {
        if (mounted) setState(() => _tzId = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveTz(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, id);
    } catch (_) {}
  }

  String get _locationName =>
      _kOptions.firstWhere(
        (o) => o.id == _tzId,
        orElse: () => _kOptions.first,
      ).locationName;

  Future<void> _showTzPicker(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? Size.zero;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + size.height,
        pos.dx + size.width,
        pos.dy + size.height + 200,
      ),
      items: _kOptions
          .map((o) => PopupMenuItem(
                value: o.id,
                child: Text(o.label),
              ))
          .toList(),
    );
    if (selected != null && mounted) {
      await _saveTz(selected);
      setState(() => _tzId = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.white.withOpacity(0.8);
    final formatted = _formatWithTz(widget.lastUpdated, _locationName);

    return GestureDetector(
      onTap: () => _showTzPicker(context),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'Last Updated: $formatted',
            style: GoogleFonts.inter(
              fontSize: widget.fontSize,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

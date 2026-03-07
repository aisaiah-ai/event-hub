import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/csv_exporter.dart';
import '../../core/utils/download_helper.dart';
import '../../features/events/data/event_repository.dart';
import '../../features/events/data/event_rsvp.dart';
import '../../models/registrant.dart';
import '../../services/registrant_service.dart';

/// Admin screen: list registrants or RSVPs for an event and export to CSV.
/// For March Cluster (march-cluster-2026) or when registrants are permission-denied, shows RSVPs.
/// Route: /admin/registrants?eventId=...
class RegistrantReportScreen extends StatefulWidget {
  const RegistrantReportScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.registrantService,
    this.eventRepository,
  });

  final String eventId;
  final String? eventTitle;
  final RegistrantService? registrantService;
  final EventRepository? eventRepository;

  @override
  State<RegistrantReportScreen> createState() => _RegistrantReportScreenState();
}

enum _ReportMode { registrants, rsvps }

class _RegistrantReportScreenState extends State<RegistrantReportScreen> {
  late RegistrantService _registrantService;
  late EventRepository _eventRepository;
  List<Registrant> _registrants = [];
  List<Registrant> _filtered = [];
  List<EventRsvp> _rsvps = [];
  List<EventRsvp> _filteredRsvps = [];
  _ReportMode _mode = _ReportMode.registrants;
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _registrantService = widget.registrantService ?? RegistrantService();
    _eventRepository = widget.eventRepository ?? EventRepository();
    _searchController.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _registrantService.listRegistrants(widget.eventId);
      if (mounted) {
        setState(() {
          _mode = _ReportMode.registrants;
          _registrants = list;
          _filtered = list;
          _loading = false;
        });
        _filter();
      }
    } catch (e) {
      final isPermissionDenied = e.toString().contains('permission-denied') ||
          e.toString().contains('permission_denied');
      if (mounted && (isPermissionDenied || widget.eventId == 'march-cluster-2026')) {
        await _loadRsvps();
        return;
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRsvps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _eventRepository.listRsvps(widget.eventId);
      if (mounted) {
        setState(() {
          _mode = _ReportMode.rsvps;
          _rsvps = list;
          _filteredRsvps = list;
          _loading = false;
        });
        _filter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (_mode == _ReportMode.registrants) {
        _filtered = q.isEmpty
            ? _registrants
            : _registrants.where((r) {
                final p = r.profile.toString().toLowerCase();
                final a = r.answers.toString().toLowerCase();
                return p.contains(q) ||
                    a.contains(q) ||
                    r.id.toLowerCase().contains(q);
              }).toList();
      } else {
        _filteredRsvps = q.isEmpty
            ? _rsvps
            : _rsvps.where((r) {
                return r.name.toLowerCase().contains(q) ||
                    r.household.toLowerCase().contains(q) ||
                    (r.area?.toLowerCase().contains(q) ?? false) ||
                    (r.cfcId?.toLowerCase().contains(q) ?? false);
              }).toList();
      }
    });
  }

  String _displayName(Registrant r) {
    final name =
        r.profile['name'] ?? r.profile['firstName'] ?? r.profile['fullName'];
    if (name?.toString().trim().isNotEmpty ?? false) {
      return name.toString().trim();
    }
    final first = r.profile['firstName'] ?? r.answers['firstName'];
    final last = r.profile['lastName'] ?? r.answers['lastName'];
    if ((first ?? last) != null) {
      return '${first ?? ''} ${last ?? ''}'.trim();
    }
    return r.id;
  }

  Future<void> _exportCsv() async {
    if (_mode == _ReportMode.registrants && _registrants.isEmpty) return;
    if (_mode == _ReportMode.rsvps && _rsvps.isEmpty) return;
    setState(() => _exporting = true);
    try {
      List<List<dynamic>> rows;
      String suffix;
      if (_mode == _ReportMode.registrants) {
        rows = _registrantListToCsvRows(_registrants);
        suffix = 'registrants';
      } else {
        rows = _rsvpListToCsvRows(_rsvps);
        suffix = 'rsvps';
      }
      final csv = toCsv(rows);
      final filename = csvFilename(widget.eventId, suffix);
      final ok = await downloadFile(filename, csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Downloaded $filename' : 'Export failed'),
            backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  List<List<dynamic>> _rsvpListToCsvRows(List<EventRsvp> list) {
    const columns = [
      'name',
      'household',
      'area',
      'attendingRally',
      'attendingDinner',
      'attendeesCount',
      'celebrationType',
      'cfcId',
      'source',
      'createdAt',
    ];
    final rows = <List<dynamic>>[
      columns,
      ...list.map((r) => [
            r.name,
            r.household,
            r.area ?? '',
            r.attendingRally,
            r.attendingDinner,
            r.attendeesCount,
            r.celebrationType ?? '',
            r.cfcId ?? '',
            r.source ?? '',
            DateFormat('yyyy-MM-dd HH:mm:ss').format(r.createdAt),
          ]),
    ];
    return rows;
  }

  /// Build header row and data rows for registrant list. Flattens profile + answers.
  List<List<dynamic>> _registrantListToCsvRows(List<Registrant> list) {
    final allKeys = <String>{};
    for (final r in list) {
      allKeys.addAll(r.profile.keys.map((e) => 'profile.$e'));
      allKeys.addAll(r.answers.keys.map((e) => 'answers.$e'));
    }
    allKeys.add('id');
    allKeys.add('source');
    allKeys.add('registrationStatus');
    allKeys.add('checkedIn');
    allKeys.add('checkedInAt');
    allKeys.add('registeredAt');
    allKeys.add('createdAt');
    final baseColumns = ['id', 'source', 'registrationStatus', 'checkedIn', 'checkedInAt', 'registeredAt', 'createdAt'];
    final extraColumns = allKeys.where((k) => !baseColumns.contains(k)).toList()..sort();
    final columns = [...baseColumns, ...extraColumns];

    String cell(Registrant r, String col) {
      if (col == 'id') return r.id;
      if (col == 'source') return r.source.name;
      if (col == 'registrationStatus') return r.registrationStatus;
      if (col == 'checkedIn') return r.eventAttendance.checkedIn.toString();
      if (col == 'checkedInAt') return r.eventAttendance.checkedInAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(r.eventAttendance.checkedInAt!) : '';
      if (col == 'registeredAt') return r.registeredAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(r.registeredAt!) : '';
      if (col == 'createdAt') return r.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(r.createdAt!) : '';
      if (col.startsWith('profile.')) {
        final key = col.substring('profile.'.length);
        final v = r.profile[key];
        return v?.toString() ?? '';
      }
      if (col.startsWith('answers.')) {
        final key = col.substring('answers.'.length);
        final v = r.answers[key];
        return v?.toString() ?? '';
      }
      return '';
    }

    final rows = <List<dynamic>>[
      columns,
      ...list.map((r) => columns.map((c) => cell(r, c)).toList()),
    ];
    return rows;
  }

  bool get _hasExportData =>
      (_mode == _ReportMode.registrants && _registrants.isNotEmpty) ||
      (_mode == _ReportMode.rsvps && _rsvps.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportLabel = _mode == _ReportMode.rsvps ? 'RSVP Report' : 'Registrant Report';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventTitle != null ? '$reportLabel — ${widget.eventTitle}' : reportLabel),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin?eventId=${widget.eventId}'),
        ),
        actions: [
          if (_hasExportData)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              onPressed: _exporting ? null : _exportCsv,
              tooltip: 'Export CSV',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _mode == _ReportMode.rsvps
                    ? 'Search by name, household, area...'
                    : 'Search by name, email, ID...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_mode == _ReportMode.rsvps) {
      if (_filteredRsvps.isEmpty) {
        return Center(
          child: Text(
            _rsvps.isEmpty ? 'No RSVPs yet' : 'No matches for "${_searchController.text}"',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _filteredRsvps.length,
        itemBuilder: (context, index) {
          final r = _filteredRsvps[index];
          return ListTile(
            title: Text(r.name),
            subtitle: Text('${r.household}${r.area != null ? ' • ${r.area}' : ''} • ${r.attendeesCount} attending'),
            trailing: Text(DateFormat.yMMMd().format(r.createdAt), style: theme.textTheme.bodySmall),
          );
        },
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          _registrants.isEmpty ? 'No registrants' : 'No matches for "${_searchController.text}"',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final r = _filtered[index];
        final name = _displayName(r);
        final subtitle = _subtitle(r);
        return ListTile(
          title: Text(name),
          subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/admin/registrants/${r.id}/edit?eventId=${widget.eventId}'),
        );
      },
    );
  }

  String? _subtitle(Registrant r) {
    final parts = <String>[];
    final email = r.profile['email'] ?? r.answers['email'];
    if (email != null && email.toString().isNotEmpty) {
      parts.add(email.toString());
    }
    if (r.eventAttendance.checkedIn) {
      parts.add('Checked in');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }
}

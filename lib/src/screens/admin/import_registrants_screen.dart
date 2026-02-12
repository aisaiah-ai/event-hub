import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/registration_schema.dart';
import '../../services/csv_import_service.dart';
import '../../services/schema_service.dart';

/// CSV import with header mapping and preview.
class ImportRegistrantsScreen extends StatefulWidget {
  const ImportRegistrantsScreen({
    super.key,
    required this.eventId,
    this.schemaService,
    this.importService,
  });

  final String eventId;
  final SchemaService? schemaService;
  final CsvImportService? importService;

  @override
  State<ImportRegistrantsScreen> createState() => _ImportRegistrantsScreenState();
}

class _ImportRegistrantsScreenState extends State<ImportRegistrantsScreen> {
  late SchemaService _schemaService;
  late CsvImportService _importService;
  RegistrationSchema? _schema;
  List<Map<String, String>> _rows = [];
  HeaderMapping _mapping = {};
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _schemaService = widget.schemaService ?? SchemaService();
    _importService = widget.importService ?? CsvImportService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await _schemaService.getSchema(widget.eventId);
    setState(() {
      _schema = s;
      _loading = false;
    });
  }

  void _parseCsv(String content) {
    _rows = _importService.parseCsv(content);
    if (_schema != null && _rows.isNotEmpty) {
      _mapping = _importService.autoMapHeaders(
        _rows.first.keys.toList(),
        _schema!,
      );
    }
    setState(() {});
  }

  Future<void> _import() async {
    if (_rows.isEmpty || _schema == null) return;
    setState(() => _importing = true);
    try {
      final result = await _importService.import(
        widget.eventId,
        _rows,
        _mapping,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${result.imported}, skipped ${result.skipped}'),
          ),
        );
        if (result.errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errors: ${result.errors.join(", ")}')),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _schema == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFf1f5f9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('Import Registrants'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import from CSV',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste your CSV content below to map columns to schema fields.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) _parseCsv(data!.text!);
                      },
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      label: const Text('Paste CSV'),
                    ),
                  ],
                ),
              ),
            ),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '${_rows.length} rows • Map headers to schema',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF64748b),
                    ),
              ),
              const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ..._rows.first.keys.map((header) {
                    return ListTile(
                      title: Text(header),
                      subtitle: DropdownButton<String>(
                        value: _mapping[header],
                        hint: const Text('Select schema field'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('-- Skip --'),
                          ),
                          ..._schema!.fields.map(
                            (f) => DropdownMenuItem(
                              value: f.key,
                              child: Text('${f.label} (${f.key})'),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            if (v != null) {
                              _mapping[header] = v;
                            } else {
                              _mapping.remove(header);
                            }
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _importing ? null : _import,
                child: _importing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Paste CSV content to get started',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF64748b),
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

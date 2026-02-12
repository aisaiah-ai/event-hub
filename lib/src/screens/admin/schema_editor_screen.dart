import 'package:flutter/material.dart';

import '../../models/field_type.dart';
import '../../widgets/styled_scaffold.dart';
import '../../models/registration_schema.dart';
import '../../models/role_override.dart';
import '../../models/schema_field.dart';
import '../../services/schema_service.dart';
import '../../widgets/dynamic_form/dynamic_form_widget.dart';

/// Admin UI for editing registration schema.
class SchemaEditorScreen extends StatefulWidget {
  const SchemaEditorScreen({
    super.key,
    required this.eventId,
    this.schemaService,
  });

  final String eventId;
  final SchemaService? schemaService;

  @override
  State<SchemaEditorScreen> createState() => _SchemaEditorScreenState();
}

class _SchemaEditorScreenState extends State<SchemaEditorScreen> {
  late SchemaService _schemaService;
  RegistrationSchema? _schema;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _schemaService = widget.schemaService ?? SchemaService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _schemaService.getSchema(widget.eventId);
      if (s == null) {
        await _schemaService.createInitialSchema(widget.eventId);
        final s2 = await _schemaService.getSchema(widget.eventId);
        setState(() => _schema = s2);
      } else {
        setState(() => _schema = s);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_schema == null) return;
    try {
      await _schemaService.saveSchema(widget.eventId, _schema!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schema saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _addField() {
    setState(() {
      final fields = List<SchemaField>.from(_schema!.fields);
      fields.add(
        SchemaField(
          key: 'field_${fields.length + 1}',
          label: 'New Field',
          type: FieldType.text,
        ),
      );
      _schema = _schema!.copyWith(fields: fields);
    });
  }

  void _editField(int index) async {
    final field = _schema!.fields[index];
    final result = await showDialog<SchemaField>(
      context: context,
      builder: (ctx) => _FieldEditDialog(field: field),
    );
    if (result != null && mounted) {
      setState(() {
        final fields = List<SchemaField>.from(_schema!.fields);
        fields[index] = result;
        _schema = _schema!.copyWith(fields: fields);
      });
    }
  }

  void _deleteField(int index) {
    final field = _schema!.fields[index];
    if (field.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locked fields cannot be removed')),
      );
      return;
    }
    setState(() {
      final fields = List<SchemaField>.from(_schema!.fields);
      fields.removeAt(index);
      _schema = _schema!.copyWith(fields: fields);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final fields = List<SchemaField>.from(_schema!.fields);
      final item = fields.removeAt(oldIndex);
      fields.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
      _schema = _schema!.copyWith(fields: fields);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFf1f5f9),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return StyledScaffold(
        title: 'Schema Editor',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('Registration Schema'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              itemCount: _schema!.fields.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final f = _schema!.fields[index];
                return Card(
                  key: ValueKey(f.key),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.drag_handle_rounded,
                      color: Color(0xFF94a3b8),
                      size: 20,
                    ),
                    title: Text(
                      '${f.label} (${f.key})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${f.type.displayName}${f.required ? " • Required" : ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748b),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          onPressed: () => _editField(index),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: f.locked
                                ? const Color(0xFFcbd5e1)
                                : const Color(0xFFf43f5e),
                          ),
                          onPressed: f.locked
                              ? null
                              : () => _deleteField(index),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add Field'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _save,
                  child: const Text('Save Schema'),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFf8fafc),
            child: Text(
              'Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0f172a),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _schema!.fields.isEmpty
                  ? const Text('No fields defined')
                  : DynamicFormWidget(
                      schema: _schema!,
                      initialValues: {},
                      role: UserRole.admin,
                      readOnly: true,
                      onSubmit: (_) {},
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEditDialog extends StatefulWidget {
  const _FieldEditDialog({required this.field});

  final SchemaField field;

  @override
  State<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends State<_FieldEditDialog> {
  late TextEditingController _keyController;
  late TextEditingController _labelController;
  late FieldType _type;
  late bool _required;
  late List<String> _options;
  late bool _locked;
  late List<String> _formationTags;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.field.key);
    _labelController = TextEditingController(text: widget.field.label);
    _type = widget.field.type;
    _required = widget.field.required;
    _options = List.from(widget.field.options);
    _locked = widget.field.locked;
    _formationTags = List.from(widget.field.formationTags.tags);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Field'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(labelText: 'Key'),
              readOnly: widget.field.locked,
            ),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            DropdownButtonFormField<FieldType>(
              // ignore: deprecated_member_use
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: FieldType.values
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.displayName)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            SwitchListTile(
              title: const Text('Required'),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
            SwitchListTile(
              title: const Text('Locked'),
              value: _locked,
              onChanged: widget.field.locked
                  ? null
                  : (v) => setState(() => _locked = v),
            ),
            if (_type == FieldType.select || _type == FieldType.multiselect)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Options (comma-separated)',
                ),
                onChanged: (v) => setState(
                  () => _options = v
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              SchemaField(
                key: _keyController.text.trim(),
                label: _labelController.text.trim(),
                type: _type,
                required: _required,
                options: _options,
                locked: _locked,
                formationTags: FormationTags(tags: _formationTags),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

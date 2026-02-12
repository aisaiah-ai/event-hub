import 'package:flutter/material.dart';

import '../../../models/field_type.dart';
import '../../../models/schema_field.dart';

/// Renders the appropriate input widget for a schema field.
class FieldRenderer extends StatelessWidget {
  const FieldRenderer({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  final SchemaField field;
  final dynamic value;
  final void Function(dynamic value) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case FieldType.text:
        return _TextInput(
          field: field,
          value: value?.toString() ?? '',
          onChanged: onChanged,
          readOnly: readOnly,
          maxLines: 1,
        );
      case FieldType.textarea:
        return _TextInput(
          field: field,
          value: value?.toString() ?? '',
          onChanged: onChanged,
          readOnly: readOnly,
          maxLines: 4,
        );
      case FieldType.email:
        return _TextInput(
          field: field,
          value: value?.toString() ?? '',
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: TextInputType.emailAddress,
        );
      case FieldType.phone:
        return _TextInput(
          field: field,
          value: value?.toString() ?? '',
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: TextInputType.phone,
        );
      case FieldType.number:
        return _TextInput(
          field: field,
          value: value?.toString() ?? '',
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
        );
      case FieldType.select:
        return _SelectInput(
          field: field,
          value: value?.toString(),
          onChanged: onChanged,
          readOnly: readOnly,
        );
      case FieldType.multiselect:
        return _MultiselectInput(
          field: field,
          value: value is List
              ? value.map((e) => e.toString()).toList()
              : value != null
              ? [value.toString()]
              : [],
          onChanged: onChanged,
          readOnly: readOnly,
        );
      case FieldType.date:
        return _DateInput(
          field: field,
          value: value is DateTime
              ? value
              : value != null
              ? DateTime.tryParse(value.toString())
              : null,
          onChanged: onChanged,
          readOnly: readOnly,
        );
      case FieldType.checkbox:
        return _CheckboxInput(
          field: field,
          value: value == true || value == 'true' || value == '1',
          onChanged: onChanged,
          readOnly: readOnly,
        );
    }
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.readOnly,
    this.keyboardType,
    this.maxLines = 1,
  });

  final SchemaField field;
  final String value;
  final void Function(dynamic) onChanged;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: readOnly ? null : (v) => onChanged(v),
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final SchemaField field;
  final String? value;
  final void Function(dynamic) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value != null && field.options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: field.options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: readOnly ? null : (v) => onChanged(v),
    );
  }
}

class _MultiselectInput extends StatelessWidget {
  const _MultiselectInput({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final SchemaField field;
  final List<String> value;
  final void Function(dynamic) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8,
        children: field.options.map((opt) {
          final selected = value.contains(opt);
          return FilterChip(
            label: Text(opt),
            selected: selected,
            onSelected: readOnly
                ? null
                : (sel) {
                    final next = List<String>.from(value);
                    if (sel) {
                      next.add(opt);
                    } else {
                      next.remove(opt);
                    }
                    onChanged(next);
                  },
          );
        }).toList(),
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final SchemaField field;
  final DateTime? value;
  final void Function(dynamic) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(field.label),
      subtitle: Text(
        value != null
            ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
            : 'Select date',
      ),
      trailing: readOnly ? null : const Icon(Icons.calendar_today),
      onTap: readOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            },
    );
  }
}

class _CheckboxInput extends StatelessWidget {
  const _CheckboxInput({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });

  final SchemaField field;
  final bool value;
  final void Function(dynamic) onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(field.label),
      value: value,
      onChanged: readOnly ? null : (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

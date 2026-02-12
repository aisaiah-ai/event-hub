import 'package:flutter/material.dart';

import '../../models/registration_schema.dart';
import '../../models/role_override.dart';
import '../../models/schema_field.dart';
import '../../validation/field_validator.dart';
import 'field_renderers/field_renderers.dart';

/// Result of form submission with profile and answers split.
class DynamicFormResult {
  const DynamicFormResult({
    required this.profile,
    required this.answers,
    this.validationWarnings = const [],
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic> answers;
  final List<String> validationWarnings;
}

/// Renders a dynamic form from registration schema with role-based validation.
class DynamicFormWidget extends StatefulWidget {
  const DynamicFormWidget({
    super.key,
    required this.schema,
    required this.onSubmit,
    this.initialValues = const {},
    this.role = UserRole.user,
    this.submitLabel = 'Save',
    this.readOnly = false,
  });

  final RegistrationSchema schema;
  final void Function(DynamicFormResult result) onSubmit;
  final Map<String, dynamic> initialValues;
  final UserRole role;
  final String submitLabel;
  final bool readOnly;

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _values = <String, dynamic>{};
  final _errors = <String, String>{};
  final _validator = const FieldValidator();

  @override
  void initState() {
    super.initState();
    _values.addAll(widget.initialValues);
  }

  @override
  void didUpdateWidget(DynamicFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValues != widget.initialValues) {
      _values.clear();
      _values.addAll(widget.initialValues);
    }
  }

  bool get _allowMissingRequired =>
      widget.schema.roleOverrides.allowMissingRequired(widget.role);

  void _onFieldChanged(String key, dynamic value) {
    setState(() {
      _values[key] = value;
      _errors.remove(key);
    });
  }

  void _submit() {
    final warnings = <String>[];
    final profile = <String, dynamic>{};
    final answers = <String, dynamic>{};
    final errors = <String, String>{};

    for (final field in widget.schema.fields) {
      final value = _values[field.key];
      final result = _validator.validate(
        field,
        value,
        !_allowMissingRequired,
      );

      if (!result.isValid) {
        if (_allowMissingRequired && field.required) {
          warnings.add(result.error!);
        } else {
          errors[field.key] = result.error!;
        }
      }

      if (errors.containsKey(field.key)) continue;

      if (field.systemField != null) {
        profile[field.key] = value;
      } else {
        answers[field.key] = value;
      }
    }

    if (errors.isNotEmpty) {
      setState(() => _errors.addAll(errors));
      return;
    }

    widget.onSubmit(DynamicFormResult(
      profile: profile,
      answers: answers,
      validationWarnings: warnings,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.schema.fields.map((field) => _buildField(field)),
          const SizedBox(height: 24),
          if (!widget.readOnly)
            FilledButton(
              onPressed: _submit,
              child: Text(widget.submitLabel),
            ),
        ],
      ),
    );
  }

  Widget _buildField(SchemaField field) {
    final error = _errors[field.key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldRenderer(
            field: field,
            value: _values[field.key],
            onChanged: (v) => _onFieldChanged(field.key, v),
            readOnly: widget.readOnly,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/registrant.dart';
import '../../models/role_override.dart';
import '../../services/registrant_service.dart';
import '../../services/schema_service.dart';
import '../../widgets/dynamic_form/dynamic_form_widget.dart';

/// Admin UI for editing an existing registrant.
class RegistrantEditScreen extends StatefulWidget {
  const RegistrantEditScreen({
    super.key,
    required this.eventId,
    required this.registrantId,
    this.schemaService,
    this.registrantService,
  });

  final String eventId;
  final String registrantId;
  final SchemaService? schemaService;
  final RegistrantService? registrantService;

  @override
  State<RegistrantEditScreen> createState() => _RegistrantEditScreenState();
}

class _RegistrantEditScreenState extends State<RegistrantEditScreen> {
  late SchemaService _schemaService;
  late RegistrantService _registrantService;
  dynamic _schema;
  Registrant? _registrant;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schemaService = widget.schemaService ?? SchemaService();
    _registrantService = widget.registrantService ?? RegistrantService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _schemaService.getSchema(widget.eventId),
      _registrantService.getRegistrant(widget.eventId, widget.registrantId),
    ]);
    setState(() {
      _schema = results[0];
      _registrant = results[1] as Registrant?;
      _loading = false;
    });
  }

  Future<void> _onSubmit(DynamicFormResult result) async {
    if (_registrant == null || _schema == null) return;
    setState(() => _saving = true);
    try {
      final updated = Registrant(
        id: _registrant!.id,
        profile: result.profile,
        answers: result.answers,
        source: _registrant!.source,
        registrationStatus: _registrant!.registrationStatus,
        registeredAt: _registrant!.registeredAt,
        createdAt: _registrant!.createdAt,
        updatedAt: DateTime.now(),
        eventAttendance: _registrant!.eventAttendance,
        flags: RegistrantFlags(
          isWalkIn: _registrant!.flags.isWalkIn,
          hasValidationWarnings: result.validationWarnings.isNotEmpty,
          validationWarnings: result.validationWarnings,
        ),
      );
      await _registrantService.saveRegistrant(widget.eventId, updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registrant updated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_registrant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Registrant')),
        body: const Center(child: Text('Registrant not found')),
      );
    }
    final schema = _schema;
    if (schema == null || schema.fields.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Registrant')),
        body: const Center(child: Text('Schema not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${_registrant!.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : DynamicFormWidget(
                schema: schema,
                initialValues: _registrant!.formValues,
                role: UserRole.admin,
                submitLabel: 'Save Changes',
                onSubmit: _onSubmit,
              ),
      ),
    );
  }
}

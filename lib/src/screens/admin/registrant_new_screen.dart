import 'package:flutter/material.dart';

import '../../models/registrant.dart';
import '../../models/registration_schema.dart';
import '../../models/registrant_source.dart';
import '../../models/role_override.dart';
import '../../services/registrant_service.dart';
import '../../services/schema_service.dart';
import '../../widgets/dynamic_form/dynamic_form_widget.dart';

/// Admin UI for creating a new registrant (manual entry).
class RegistrantNewScreen extends StatefulWidget {
  const RegistrantNewScreen({
    super.key,
    required this.eventId,
    required this.role,
    this.schemaService,
    this.registrantService,
  });

  final String eventId;
  final UserRole role;
  final SchemaService? schemaService;
  final RegistrantService? registrantService;

  @override
  State<RegistrantNewScreen> createState() => _RegistrantNewScreenState();
}

class _RegistrantNewScreenState extends State<RegistrantNewScreen> {
  late SchemaService _schemaService;
  late RegistrantService _registrantService;
  RegistrationSchema? _schema;
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
    final s = await _schemaService.getSchema(widget.eventId);
    setState(() {
      _schema = s;
      _loading = false;
    });
  }

  Future<void> _onSubmit(DynamicFormResult result) async {
    setState(() => _saving = true);
    try {
      final registrant = Registrant(
        id: '',
        profile: result.profile,
        answers: result.answers,
        source: RegistrantSource.manual,
        flags: RegistrantFlags(
          isWalkIn: true,
          hasValidationWarnings: result.validationWarnings.isNotEmpty,
          validationWarnings: result.validationWarnings,
        ),
        registeredAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final id = await _registrantService.saveRegistrant(widget.eventId, registrant);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrant created: $id')),
        );
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _schema == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_schema!.fields.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFf1f5f9),
        appBar: AppBar(title: const Text('New Registrant')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schema_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Define schema fields first',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to Schema Editor to add registration fields.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text('New Registrant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _saving
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DynamicFormWidget(
                    schema: _schema!,
                    initialValues: {},
                    role: widget.role,
                    submitLabel: 'Create Registrant',
                    onSubmit: _onSubmit,
                  ),
                ),
              ),
      ),
    );
  }
}

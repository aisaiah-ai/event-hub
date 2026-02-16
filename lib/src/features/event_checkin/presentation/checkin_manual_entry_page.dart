import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../models/registrant.dart';
import '../../../models/registrant_source.dart';
import '../../../services/registrant_service.dart';
import '../../events/data/event_model.dart';
import '../../events/data/event_repository.dart';
import '../../events/event_tokens.dart';
import '../../events/widgets/event_page_scaffold.dart';
import '../data/checkin_repository.dart';

/// Manual check-in for walk-ins: create minimal registrant then session check-in.
class CheckinManualEntryPage extends StatefulWidget {
  const CheckinManualEntryPage({
    super.key,
    required this.eventId,
    required this.eventSlug,
    required this.sessionId,
    this.repository,
  });

  final String eventId;
  final String eventSlug;
  final String sessionId;
  final CheckinRepository? repository;

  @override
  State<CheckinManualEntryPage> createState() => _CheckinManualEntryPageState();
}

class _CheckinManualEntryPageState extends State<CheckinManualEntryPage> {
  late CheckinRepository _repo;
  late RegistrantService _registrantService;
  EventModel? _event;
  bool _loadingEvent = true;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _chapterController = TextEditingController();
  final _roleController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CheckinRepository();
    _registrantService = RegistrantService();
    _loadEvent();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _chapterController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    final event = await EventRepository().getEventBySlug(widget.eventSlug);
    if (mounted) setState(() {
      _event = event;
      _loadingEvent = false;
    });
  }

  Future<void> _submit() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'First and last name required');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final walkIn = Registrant(
        id: '',
        profile: {
          'firstName': first,
          'lastName': last,
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          if (_chapterController.text.trim().isNotEmpty)
            'chapter': _chapterController.text.trim(),
          if (_roleController.text.trim().isNotEmpty)
            'role': _roleController.text.trim(),
        },
        answers: {},
        source: RegistrantSource.manual,
        flags: const RegistrantFlags(isWalkIn: true),
      );
      final registrantId = await _registrantService.saveRegistrant(
        widget.eventId,
        walkIn,
        triggerFormation: false,
      );
      await _repo.checkInSessionOnly(
        widget.eventId,
        widget.sessionId,
        registrantId,
        source: 'manual',
        method: CheckinMethod.manual,
      );
      if (!mounted) return;
      context.pop({
        'success': true,
        'name': '$first $last'.trim(),
      });
    } catch (e) {
      if (mounted) setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEvent) {
      return EventPageScaffold(
        event: null,
        body: const Center(
          child: CircularProgressIndicator(color: EventTokens.textOffWhite),
        ),
      );
    }

    return EventPageScaffold(
      event: _event,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EventTokens.textOffWhite),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Enter Manually',
          style: TextStyle(color: EventTokens.textOffWhite),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(EventTokens.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField('First name *', _firstNameController),
            const SizedBox(height: EventTokens.spacingM),
            _buildField('Last name *', _lastNameController),
            const SizedBox(height: EventTokens.spacingM),
            _buildField('Email (optional)', _emailController),
            const SizedBox(height: EventTokens.spacingM),
            _buildField('Chapter', _chapterController),
            const SizedBox(height: EventTokens.spacingM),
            _buildField('Role (optional)', _roleController),
            if (_error != null) ...[
              const SizedBox(height: EventTokens.spacingM),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: EventTokens.spacingXL),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _event?.accentColor ?? EventTokens.accentGold,
                foregroundColor: EventTokens.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: EventTokens.spacingL),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EventTokens.radiusMedium),
        ),
      ),
      style: const TextStyle(color: EventTokens.textOffWhite),
    );
  }
}

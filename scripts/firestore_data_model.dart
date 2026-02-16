/// Canonical Firestore data model: paths, parent requirements, and who creates them.
///
/// Run: `dart run scripts/firestore_data_model.dart`
/// Output: prints to stdout and writes docs/FIRESTORE_DATA_MODEL.md
///
/// When you get permission-denied or not-found: check this model first.
/// Ensure PARENT documents exist in the target database (event-hub-dev / event-hub-prod)
/// before writing to subcollections.

import 'dart:io';

void main(List<String> args) {
  final out = StringBuffer();
  out.writeln('# Firestore Data Model (event-hub-dev / event-hub-prod)');
  out.writeln();
  out.writeln('**When you get an error:** check that the document/collection in the error message has its PARENT created first. Use this doc and the checklist below.');
  out.writeln();
  out.writeln('---');
  out.writeln();

  for (final e in allEntries) {
    out.writeln('## ${e.path}');
    out.writeln();
    out.writeln('- **Parent must exist:** ${e.parentMustExist}');
    out.writeln('- **Created by:** ${e.createdBy}');
    if (e.notes.isNotEmpty) out.writeln('- **Notes:** ${e.notes}');
    out.writeln();
  }

  out.writeln('---');
  out.writeln();
  out.writeln('## Error troubleshooting checklist');
  out.writeln();
  out.writeln('1. **Database:** App uses named DB only (`event-hub-dev` or `event-hub-prod`). Never `(default)`.');
  out.writeln('2. **Event doc:** Before any check-in or registrant read, `events/{eventId}` must exist (e.g. `events/nlc-2026`).');
  out.writeln('3. **Session doc:** Before writing to `.../sessions/{sessionId}/attendance/...`, the document `events/{eventId}/sessions/{sessionId}` must exist.');
  out.writeln('4. **Session check-in (only):** All writes to `events/{eventId}/sessions/{sessionId}/attendance/{registrantId}`. Parent session doc must exist. No /checkins.');
  out.writeln('5. **Bootstrap:** Use Firebase Console or `ensure-nlc-event-doc.js` to create event + session documents (including main-checkin) first.');
  out.writeln('6. **Rules:** Deploy rules to the database the app uses: `firebase deploy --only firestore:rules`.');
  out.writeln();

  final s = out.toString();
  print(s);

  try {
    final file = File('docs/FIRESTORE_DATA_MODEL.md');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(s);
    print('Wrote docs/FIRESTORE_DATA_MODEL.md');
  } catch (e) {
    print('Could not write file: $e');
  }
}

class _Entry {
  const _Entry({
    required this.path,
    required this.parentMustExist,
    required this.createdBy,
    this.notes = '',
  });
  final String path;
  final String parentMustExist;
  final String createdBy;
  final String notes;
}

const _eventId = '{eventId}';
const _sessionId = '{sessionId}';
const _registrantId = '{registrantId}';

const allEntries = [
  _Entry(
    path: 'events/$_eventId',
    parentMustExist: 'None (root)',
    createdBy: 'Bootstrap / admin. Must exist before any subcollection write.',
    notes: 'e.g. events/nlc-2026',
  ),
  _Entry(
    path: 'events/$_eventId/registrants/$_registrantId',
    parentMustExist: 'events/$_eventId',
    createdBy: 'App (staff import) or seed script',
    notes: 'Registrant profile + answers. Read by check-in search.',
  ),
  _Entry(
    path: 'events/$_eventId/sessions/$_sessionId',
    parentMustExist: 'events/$_eventId',
    createdBy: 'Bootstrap. Must exist before writing to attendance.',
    notes: 'e.g. events/nlc-2026/sessions/main-checkin, events/nlc-2026/sessions/gender-ideology-dialogue',
  ),
  _Entry(
    path: 'events/$_eventId/sessions/$_sessionId/attendance/$_registrantId',
    parentMustExist: 'events/$_eventId/sessions/$_sessionId (session doc must exist)',
    createdBy: 'App (session check-in). Pure session architecture: all check-in writes here.',
    notes: 'CheckInService reads session doc first; then writes here. Main Check-In uses session main-checkin.',
  ),
  _Entry(
    path: 'events/$_eventId/rsvps/{rsvpId}',
    parentMustExist: 'events/$_eventId',
    createdBy: 'App (public RSVP)',
  ),
  _Entry(
    path: 'events/$_eventId/admins/{email}',
    parentMustExist: 'events/$_eventId',
    createdBy: 'Admin / bootstrap',
  ),
  _Entry(
    path: 'events/$_eventId/schemas/{docId}',
    parentMustExist: 'events/$_eventId',
    createdBy: 'Admin',
  ),
  _Entry(
    path: 'events/$_eventId/stats/overview',
    parentMustExist: 'events/$_eventId',
    createdBy: 'Bootstrap; Cloud Functions update',
  ),
  _Entry(
    path: 'events/$_eventId/formationSignals/$_registrantId',
    parentMustExist: 'events/$_eventId',
    createdBy: 'App (after check-in) or Cloud Functions',
  ),
  _Entry(
    path: 'events/$_eventId/importMappings/{mappingId}',
    parentMustExist: 'events/$_eventId',
    createdBy: 'App (staff import)',
  ),
];

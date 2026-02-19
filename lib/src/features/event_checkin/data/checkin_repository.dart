import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../config/firestore_config.dart';
import '../../../models/checkin_record.dart' show CheckinMethod;
import '../../../models/registrant.dart';
import '../../../models/session.dart';
import '../../../../services/checkin_service.dart';
import '../../../services/registrant_service.dart';
import '../../../services/session_service.dart';
import 'nlc_sessions.dart';
export '../../../models/checkin_record.dart' show CheckinMethod;

/// Result of checking in to a session, with optional conference (main-checkin) check-in.
typedef CheckInResult = ({bool didSessionCheckIn, bool didConferenceCheckIn});

// ignore: avoid_print
void _checkinLog(String msg) => print('[CheckinRepository] $msg');

/// Repository for self-check-in. Pure session: all writes to
/// events/{eventId}/sessions/{sessionId}/attendance/{registrantId}.
/// No /checkins collection.
class CheckinRepository {
  CheckinRepository({
    FirebaseFirestore? firestore,
    RegistrantService? registrantService,
    SessionService? sessionService,
    CheckInService? checkInService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _registrantService =
            registrantService ?? RegistrantService(firestore: firestore),
        _sessionService =
            sessionService ?? SessionService(firestore: firestore),
        _checkInService = checkInService ?? CheckInService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final RegistrantService _registrantService;
  final SessionService _sessionService;
  final CheckInService _checkInService;

  /// Whether the registrant is checked in to this session (attendance doc exists).
  /// Returns false on permission-denied so the UI stays tappable.
  Future<bool> isCheckedIn({
    required String eventId,
    required String sessionId,
    required String registrantId,
  }) async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('sessions')
          .doc(sessionId)
          .collection('attendance')
          .doc(registrantId)
          .get();
      return doc.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Whether registrant is in this session's attendance (alias for isCheckedIn).
  Future<bool> hasSessionAttendance(
    String eventId,
    String sessionId,
    String registrantId,
  ) async {
    return _sessionService.hasSessionAttendance(
      eventId,
      sessionId,
      registrantId,
    );
  }

  /// (exists, checkedInAt) for badge + timestamp UI.
  Future<({bool exists, DateTime? checkedInAt})> getSessionAttendanceInfo(
    String eventId,
    String sessionId,
    String registrantId,
  ) async {
    return _sessionService.getSessionAttendanceInfo(
      eventId,
      sessionId,
      registrantId,
    );
  }

  /// Recent check-ins for this session (name + time), most recent first. For the check-in page log.
  Future<List<({String name, DateTime timestamp})>> getRecentCheckins(
    String eventId,
    String sessionId, {
    int limit = 10,
  }) async {
    try {
      final attSnap = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('sessions')
          .doc(sessionId)
          .collection('attendance')
          .orderBy('checkedInAt', descending: true)
          .limit(limit)
          .get();
      final results = <({String name, DateTime timestamp})>[];
      for (final d in attSnap.docs) {
        final data = d.data();
        final ts = data['createdAt'] ?? data['checkedInAt'];
        final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
        final reg = await _registrantService.getRegistrant(eventId, d.id);
        final name = reg != null
            ? (reg.profile['name'] ?? reg.profile['firstName'] ?? reg.answers['name'] ?? reg.answers['firstName'])
                ?.toString()
                .trim()
            : null;
        final first = reg?.profile['firstName'] ?? reg?.answers['firstName'];
        final last = reg?.profile['lastName'] ?? reg?.answers['lastName'];
        final displayName = (name != null && name.isNotEmpty)
            ? name
            : (first != null || last != null)
                ? '${first ?? ''} ${last ?? ''}'.trim()
                : 'Guest';
        results.add((name: displayName.isEmpty ? 'Guest' : displayName, timestamp: dt));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Active sessions for session selector.
  Future<List<Session>> getActiveSessions(String eventId) async {
    return _sessionService.getActiveSessions(eventId);
  }

  /// Sessions ordered by Firestore 'order' (NLC 2026: no hardcoded lists).
  Future<List<Session>> getSessionsOrderedByOrder(String eventId) async {
    return _sessionService.getSessionsOrderedByOrder(eventId);
  }

  /// Get registrant by ID.
  Future<Registrant?> getRegistrant(String eventId, String registrantId) async {
    return _registrantService.getRegistrant(eventId, registrantId);
  }

  /// Find registrant by CFC ID or email (for QR scan).
  Future<Registrant?> findRegistrantByCfcIdOrEmail(
    String eventId,
    String identifier,
  ) async {
    final trimmed = identifier.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final registrants = await _registrantService.listRegistrants(eventId);
    for (final r in registrants) {
      final cfcId = (r.profile['cfcId'] ?? r.answers['cfcId'])?.toString();
      final email = (r.profile['email'] ?? r.answers['email'])?.toString();
      if (cfcId != null && cfcId.toLowerCase() == trimmed) return r;
      if (email != null && email.toLowerCase() == trimmed) return r;
    }
    return null;
  }

  /// Search registrants. Uses lastNameSearchIndex when available (scalable).
  Future<List<Registrant>> searchRegistrants(
    String eventId,
    String query, {
    int limit = 15,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    try {
      final indexResults = await _registrantService.searchByLastNameIndex(
        eventId,
        q,
        limit: limit,
      );
      if (indexResults.isNotEmpty) return indexResults;
    } catch (_) {}

    final all = await _registrantService.listRegistrants(eventId);
    final results = <Registrant>[];
    for (final r in all) {
      if (results.length >= limit) break;
      final first =
          (r.profile['firstName'] ?? r.answers['firstName'])?.toString() ?? '';
      final last =
          (r.profile['lastName'] ?? r.answers['lastName'])?.toString() ?? '';
      final name = (r.profile['name'] ?? r.answers['name'])?.toString() ?? '';
      final email =
          (r.profile['email'] ?? r.answers['email'])?.toString() ?? '';
      final cfcId =
          (r.profile['cfcId'] ?? r.answers['cfcId'])?.toString() ?? '';
      final searchable = '$first $last $name $email $cfcId'.toLowerCase();
      if (searchable.contains(q)) results.add(r);
    }
    return results;
  }

  /// Check in to session. Writes to events/{eventId}/sessions/{sessionId}/attendance/{registrantId}. Idempotent.
  Future<bool> checkIn(
    String eventId,
    String sessionId,
    String registrantId, {
    String checkedInBy = 'self',
  }) async {
    return _checkInService.checkIn(
      eventId: eventId,
      sessionId: sessionId,
      registrantId: registrantId,
      checkedInBy: checkedInBy,
    );
  }

  /// Check in to session; if session is not main-checkin, also check in to conference (main-checkin) first if not already.
  /// Returns whether the session check-in created a new doc and whether we created a conference (main-checkin) doc.
  Future<CheckInResult> checkInSessionAndConferenceIfNeeded(
    String eventId,
    String sessionId,
    String registrantId, {
    String checkedInBy = 'self',
  }) async {
    if (sessionId == NlcSessions.mainCheckInSessionId) {
      final did = await checkIn(eventId, sessionId, registrantId, checkedInBy: checkedInBy);
      return (didSessionCheckIn: did, didConferenceCheckIn: false);
    }
    // Ensure conference (main-checkin) first.
    bool didConference = false;
    final hasConference = await isCheckedIn(
      eventId: eventId,
      sessionId: NlcSessions.mainCheckInSessionId,
      registrantId: registrantId,
    );
    if (!hasConference) {
      didConference = await checkIn(
        eventId,
        NlcSessions.mainCheckInSessionId,
        registrantId,
        checkedInBy: checkedInBy,
      );
    }
    final didSession = await checkIn(eventId, sessionId, registrantId, checkedInBy: checkedInBy);
    return (didSessionCheckIn: didSession, didConferenceCheckIn: didConference);
  }

  /// Session check-in from landing (QR/manual). Uses SessionService; triggers formation signal.
  Future<void> checkInSessionOnly(
    String eventId,
    String sessionId,
    String registrantId, {
    String source = 'self',
    CheckinMethod method = CheckinMethod.search,
  }) async {
    final already = await _sessionService.hasSessionAttendance(
      eventId,
      sessionId,
      registrantId,
    );
    if (already) return;
    try {
      await _sessionService.checkInSessionOnly(
        eventId,
        sessionId,
        registrantId,
        source,
      );
    } catch (e, st) {
      _checkinLog('checkInSessionOnly FAILED at session attendance');
      _checkinLog('  eventId: $eventId sessionId: $sessionId registrantId: $registrantId');
      _checkinLog('  database: ${FirestoreConfig.databaseId}');
      _checkinLog('  error: $e');
      _checkinLog('  stack: $st');
      rethrow;
    }
  }
}

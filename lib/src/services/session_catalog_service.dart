import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/session.dart';
import 'session_registration_service.dart';

/// UI availability label for a session.
enum SessionAvailabilityLabel {
  available,
  almostFull,
  full,
  closed,
}

/// Session with computed availability for UI.
/// Remaining = capacity − preRegisteredCount − nonRegisteredCheckIn (pre-registered have priority).
class SessionWithAvailability {
  const SessionWithAvailability({
    required this.session,
    required this.remainingSeats,
    required this.label,
    this.preRegisteredCount = 0,
    this.preRegisteredCheckedIn = 0,
  });

  final Session session;
  /// Remaining seats: capacity − preRegistered (reserved) − non‑registered check-ins.
  final int remainingSeats;
  final SessionAvailabilityLabel label;
  /// Number of registrants pre-registered for this session (from sessionRegistrations).
  final int preRegisteredCount;
  /// Number of checked-in attendees who are pre-registered for this session.
  final int preRegisteredCheckedIn;
}

/// All four attendance numbers per session in one place.
/// Use [getSessionAttendanceBreakdowns] to fetch.
class SessionAttendanceBreakdown {
  const SessionAttendanceBreakdown({
    required this.sessionId,
    required this.sessionName,
    required this.totalPreRegistered,
    required this.totalCheckedIn,
    required this.preRegisteredCheckedIn,
    required this.walkInCheckedIn,
  });

  final String sessionId;
  final String sessionName;
  /// Total registrants pre-registered for this session (sessionRegistrations).
  final int totalPreRegistered;
  /// Total check-ins for this session (attendance subcollection count).
  final int totalCheckedIn;
  /// Check-ins who were pre-registered for this session.
  final int preRegisteredCheckedIn;
  /// Check-ins who were not pre-registered (walk-ins).
  final int walkInCheckedIn;
}

/// Lists and watches sessions; computes availability (remaining seats, status label).
class SessionCatalogService {
  SessionCatalogService({
    FirebaseFirestore? firestore,
    SessionRegistrationService? sessionRegistrationService,
  })  : _firestore = firestore ?? FirestoreConfig.instance,
        _sessionRegistrationService =
            sessionRegistrationService ?? SessionRegistrationService();

  final FirebaseFirestore _firestore;
  final SessionRegistrationService _sessionRegistrationService;

  String _sessionsPath(String eventId) => 'events/$eventId/sessions';

  /// List all sessions for an event (order by order, then by id).
  Future<List<Session>> listSessions(String eventId) async {
    final snap = await _firestore
        .collection(_sessionsPath(eventId))
        .orderBy('order')
        .get();
    return snap.docs
        .map((d) => Session.fromFirestore(d.id, d.data()))
        .toList();
  }

  /// Stream of sessions for real-time UI.
  Stream<List<Session>> watchSessions(String eventId) {
    return _firestore
        .collection(_sessionsPath(eventId))
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Session.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Get a single session by id.
  Future<Session?> getSession(String eventId, String sessionId) async {
    final ref = _firestore.doc('${_sessionsPath(eventId)}/$sessionId');
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return null;
    return Session.fromFirestore(snap.id, snap.data()!);
  }

  /// Main session (isMain == true). Cached per event in memory if needed; here we query.
  Future<String?> getMainSessionId(String eventId) async {
    final snap = await _firestore
        .collection(_sessionsPath(eventId))
        .where('isMain', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Availability label based on actual open seats (capacity − attendanceCount).
  static SessionAvailabilityLabel availabilityLabelFromRemaining(
    Session s,
    int remainingSeats,
  ) {
    if (s.capacity <= 0) return SessionAvailabilityLabel.available;
    final open = (s.capacity - s.attendanceCount).clamp(0, s.capacity);
    if (open <= 0) return SessionAvailabilityLabel.full;
    if (open <= 5) return SessionAvailabilityLabel.almostFull;
    return SessionAvailabilityLabel.available;
  }

  /// Legacy: availability from session.remainingSeats (capacity − attendanceCount). Prefer listSessionsWithAvailability.
  static SessionAvailabilityLabel availabilityLabel(Session s) {
    if (s.status == SessionStatus.closed) return SessionAvailabilityLabel.closed;
    if (s.capacity <= 0) return SessionAvailabilityLabel.available;
    if (s.attendanceCount >= s.capacity) return SessionAvailabilityLabel.full;
    final remaining = s.capacity - s.attendanceCount;
    if (remaining <= 5) return SessionAvailabilityLabel.almostFull;
    return SessionAvailabilityLabel.available;
  }

  /// Remaining seats with pre-registered priority: capacity − preRegisteredCount − (attendanceCount − preRegisteredCheckedIn).
  static int remainingWithPreRegPriority({
    required int capacity,
    required int attendanceCount,
    required int preRegisteredCount,
    required int preRegisteredCheckedIn,
  }) {
    if (capacity <= 0) return 0x7FFFFFFF;
    final nonRegisteredCheckIn = attendanceCount - preRegisteredCheckedIn;
    return (capacity - preRegisteredCount - nonRegisteredCheckIn).clamp(0, 0x7FFFFFFF);
  }

  /// Status string for chip: Available / Almost Full / Full / Closed.
  static String availabilityLabelString(SessionAvailabilityLabel label) {
    switch (label) {
      case SessionAvailabilityLabel.available:
        return 'Available';
      case SessionAvailabilityLabel.almostFull:
        return 'Almost Full';
      case SessionAvailabilityLabel.full:
        return 'Full';
      case SessionAvailabilityLabel.closed:
        return 'Closed';
    }
  }

  /// Attendance registrant IDs for a session (doc IDs in attendance subcollection).
  Future<Set<String>> _getAttendanceRegistrantIds(
    String eventId,
    String sessionId,
  ) async {
    final snap = await _firestore
        .collection(_sessionsPath(eventId))
        .doc(sessionId)
        .collection('attendance')
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// List sessions with availability UI model. Remaining = capacity − preRegistered − nonRegisteredCheckIn (pre-reg priority).
  Future<List<SessionWithAvailability>> listSessionsWithAvailability(
    String eventId,
  ) async {
    final sessions = await listSessions(eventId);
    final preRegCounts =
        await _sessionRegistrationService.getPreRegisteredCountsPerSession(eventId);
    final results = <SessionWithAvailability>[];
    for (final s in sessions) {
      final preRegisteredCount = preRegCounts[s.id] ?? 0;
      int preRegisteredCheckedIn = 0;
      int remainingSeats = s.capacity > 0 ? (s.capacity - s.attendanceCount).clamp(0, 0x7FFFFFFF) : 0x7FFFFFFF;
      if (s.capacity > 0) {
        final preRegIds = await _sessionRegistrationService
            .getRegistrantIdsPreRegisteredForSession(eventId, s.id);
        final attendanceIds = await _getAttendanceRegistrantIds(eventId, s.id);
        preRegisteredCheckedIn = preRegIds.intersection(attendanceIds).length;
        remainingSeats = remainingWithPreRegPriority(
          capacity: s.capacity,
          attendanceCount: s.attendanceCount,
          preRegisteredCount: preRegisteredCount,
          preRegisteredCheckedIn: preRegisteredCheckedIn,
        );
      }
      final label = availabilityLabelFromRemaining(s, remainingSeats);
      results.add(SessionWithAvailability(
        session: s,
        remainingSeats: remainingSeats,
        label: label,
        preRegisteredCount: preRegisteredCount,
        preRegisteredCheckedIn: preRegisteredCheckedIn,
      ));
    }
    return results;
  }

  /// All four numbers per session: total pre-registered, total check-in, pre-reg check-in, walk-in check-in.
  /// Single API for dashboards, exports, or reports.
  Future<List<SessionAttendanceBreakdown>> getSessionAttendanceBreakdowns(
    String eventId,
  ) async {
    final list = await listSessionsWithAvailability(eventId);
    return list
        .map((e) => SessionAttendanceBreakdown(
              sessionId: e.session.id,
              sessionName: e.session.displayName,
              totalPreRegistered: e.preRegisteredCount,
              totalCheckedIn: e.session.attendanceCount,
              preRegisteredCheckedIn: e.preRegisteredCheckedIn,
              walkInCheckedIn:
                  e.session.attendanceCount - e.preRegisteredCheckedIn,
            ))
        .toList();
  }

  /// Stream of the same breakdown for reactive UIs (e.g. dashboard).
  Stream<List<SessionAttendanceBreakdown>> watchSessionAttendanceBreakdowns(
    String eventId,
  ) {
    return watchSessionsWithAvailability(eventId).asyncMap((_) async {
      return getSessionAttendanceBreakdowns(eventId);
    });
  }

  /// Stream sessions with availability. Remaining = capacity − preRegistered − nonRegisteredCheckIn (pre-reg priority).
  Stream<List<SessionWithAvailability>> watchSessionsWithAvailability(
    String eventId,
  ) {
    return watchSessions(eventId).asyncMap((sessions) async {
      return listSessionsWithAvailability(eventId);
    });
  }

  /// Single session with availability (remaining with pre-reg priority). Use when only one session is needed.
  Future<SessionWithAvailability?> getSessionWithAvailability(
    String eventId,
    String sessionId,
  ) async {
    final list = await listSessionsWithAvailability(eventId);
    try {
      return list.firstWhere((e) => e.session.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  /// Filter to sessions that are available (open and not full). Optionally filter to given ids.
  Future<List<SessionWithAvailability>> listAvailableSessions(
    String eventId, {
    List<String>? filterSessionIds,
  }) async {
    final list = await listSessionsWithAvailability(eventId);
    var result = list.where((e) =>
        e.label != SessionAvailabilityLabel.full &&
        e.label != SessionAvailabilityLabel.closed);
    if (filterSessionIds != null && filterSessionIds.isNotEmpty) {
      final set = filterSessionIds.toSet();
      result = result.where((e) => set.contains(e.session.id));
    }
    return result.toList();
  }
}

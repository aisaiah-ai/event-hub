import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_config.dart';
import '../models/session.dart';

/// UI availability label for a session.
enum SessionAvailabilityLabel {
  available,
  almostFull,
  full,
  closed,
}

/// Session with computed availability for UI.
class SessionWithAvailability {
  const SessionWithAvailability({
    required this.session,
    required this.remainingSeats,
    required this.label,
  });

  final Session session;
  final int remainingSeats;
  final SessionAvailabilityLabel label;
}

/// Lists and watches sessions; computes availability (remaining seats, status label).
class SessionCatalogService {
  SessionCatalogService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

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

  /// Compute availability label from session.
  static SessionAvailabilityLabel availabilityLabel(Session s) {
    if (s.status == SessionStatus.closed) return SessionAvailabilityLabel.closed;
    if (s.capacity <= 0) return SessionAvailabilityLabel.available;
    if (s.attendanceCount >= s.capacity) return SessionAvailabilityLabel.full;
    final remaining = s.capacity - s.attendanceCount;
    if (remaining <= 5) return SessionAvailabilityLabel.almostFull;
    return SessionAvailabilityLabel.available;
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

  /// List sessions with availability UI model.
  Future<List<SessionWithAvailability>> listSessionsWithAvailability(
    String eventId,
  ) async {
    final sessions = await listSessions(eventId);
    return sessions.map((s) {
      final remaining = s.remainingSeats;
      final label = availabilityLabel(s);
      return SessionWithAvailability(
        session: s,
        remainingSeats: remaining,
        label: label,
      );
    }).toList();
  }

  /// Stream sessions with availability.
  Stream<List<SessionWithAvailability>> watchSessionsWithAvailability(
    String eventId,
  ) {
    return watchSessions(eventId).asyncMap((sessions) {
      return sessions.map((s) {
        final remaining = s.remainingSeats;
        final label = availabilityLabel(s);
        return SessionWithAvailability(
          session: s,
          remainingSeats: remaining,
          label: label,
        );
      }).toList();
    });
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

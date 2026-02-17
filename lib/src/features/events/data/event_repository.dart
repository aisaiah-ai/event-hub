import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../config/firestore_config.dart';
import 'event_model.dart';
import 'event_rsvp.dart';

/// Repository for public events (events subdomain).
/// Uses FirestoreConfig for named databases (event-hub-dev, event-hub-prod).
class EventRepository {
  EventRepository() : _firestore = FirestoreConfig.instanceOrNull;

  final FirebaseFirestore? _firestore;

  static const String _eventsCollection = 'events';

  /// Fetch event by ID.
  Future<EventModel?> getEventById(String eventId) async {
    final fs = _firestore;
    if (fs == null) return null;
    try {
      final snap = await fs
          .collection(_eventsCollection)
          .doc(eventId)
          .get();
      if (snap.exists && snap.data() != null) {
        return EventModel.fromFirestore(snap);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch event by slug from events collection.
  /// In debug mode, returns fallback for march-cluster-2026 if not in Firestore or on permission error.
  Future<EventModel?> getEventBySlug(String slug) async {
    final fs = _firestore;
    if (fs == null) {
      return slug == 'march-cluster-2026' ? _marchCluster2026Fallback : null;
    }
    try {
      final snapshot = await fs
          .collection(_eventsCollection)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return EventModel.fromFirestore(snapshot.docs.first);
      }
      // NLC: event doc is at events/nlc-2026; slug query may miss if slug field differs
      if (slug == 'nlc-2026') {
        final byId = await getEventById('nlc-2026');
        if (byId != null) return byId;
        return _nlcFallback;
      }
    } catch (e) {
      if (slug == 'march-cluster-2026') return _marchCluster2026Fallback;
      if (slug == 'nlc' || slug == 'nlc-2026') return _nlcFallback;
      rethrow;
    }

    if (slug == 'march-cluster-2026') return _marchCluster2026Fallback;
    if (slug == 'nlc' || slug == 'nlc-2026') return _nlcFallback;
    return null;
  }

  static final EventModel _nlcFallback = EventModel(
    id: 'nlc-2026',
    slug: 'nlc',
    name: 'National Leaders Conference',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 1),
    locationName: 'Hyatt Regency Valencia | Grand Ballroom',
    address: '24500 Town Center Dr., Valencia, CA 91355',
    isActive: true,
    allowRsvp: false,
    allowCheckin: true,
    metadata: {
      'selfCheckinEnabled': true,
      'sessionsEnabled': true,
    },
    logoUrl: 'assets/checkin/IntheOne.svg',
    backgroundImageUrl: 'assets/images/nlc_background.png',
    backgroundPatternUrl: 'assets/checkin/mossaic.svg',
    organizationName: 'Couples for Christ',
  );

  static final EventModel _marchCluster2026Fallback = EventModel(
    id: 'march-cluster-2026',
    slug: 'march-cluster-2026',
    name:
        'March Cluster Central B (BBS, Tampa, Port Charlotte) Assembly, Evangelization Rally & Fellowship night',
    startDate: DateTime(2026, 3, 14),
    endDate: DateTime(2026, 3, 14),
    locationName: "St. Michael's Hall",
    address:
        "Incarnation Catholic Church, 8220 W Hillsborough Ave, Tampa, FL 33615",
    isActive: true,
    allowRsvp: true,
    allowCheckin: false,
    metadata: {
      'rallyTime': '3:00 PM - 6:00 PM',
      'dinnerTime': '6:00 PM - 9:00 PM',
      'rsvpDeadline': 'March 10',
    },
    logoUrl: 'assets/checkin/IntheOne.svg',
    backgroundPatternUrl: 'assets/checkin/mossaic.svg',
    organizationName: 'Couples for Christ',
  );

  /// Get the currently active event (for events.aisaiah.org root redirect).
  /// In debug mode, falls back to march-cluster-2026 if no active event or on error.
  Future<EventModel?> getActiveEvent() async {
    final fs = _firestore;
    if (fs == null) return _marchCluster2026Fallback;
    try {
      final snapshot = await fs
          .collection(_eventsCollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return EventModel.fromFirestore(snapshot.docs.first);
      }
    } catch (_) {
      return _marchCluster2026Fallback;
    }
    // No active event in Firestore: use march-cluster as default
    return _marchCluster2026Fallback;
  }

  /// Submit RSVP for an event.
  /// Throws if Firestore is not available (named database not created).
  Future<void> submitRsvp(String eventId, EventRsvp rsvp) async {
    final fs = _firestore;
    if (fs == null) {
      final dbId = FirestoreConfig.databaseId;
      throw StateError(
        'Firestore not configured. Create the $dbId database in Firebase Console.',
      );
    }
    await fs
        .collection(_eventsCollection)
        .doc(eventId)
        .collection('rsvps')
        .add(rsvp.toFirestore());
  }
}

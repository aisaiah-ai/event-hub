import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../config/firestore_config.dart';
import 'event_model.dart';
import 'event_rsvp.dart';

/// Repository for public events (events subdomain).
/// Uses FirestoreConfig for named databases (event-hub-dev, event-hub-prod).
class EventRepository {
  EventRepository() : _firestore = FirestoreConfig.instance;

  final FirebaseFirestore _firestore;

  static const String _eventsCollection = 'events';

  /// Fetch event by slug from events collection.
  /// In debug mode, returns fallback for march-cluster-2026 if not in Firestore or on permission error.
  Future<EventModel?> getEventBySlug(String slug) async {
    try {
      final snapshot = await _firestore
          .collection(_eventsCollection)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return EventModel.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      if (kDebugMode && slug == 'march-cluster-2026') {
        return _marchCluster2026Fallback;
      }
      rethrow;
    }

    if (kDebugMode && slug == 'march-cluster-2026') {
      return _marchCluster2026Fallback;
    }
    return null;
  }

  static final EventModel _marchCluster2026Fallback = EventModel(
    id: 'march-cluster-2026',
    slug: 'march-cluster-2026',
    name: 'March Cluster Central B (BBS, Tampa, Port Charlotte) Assembly, Evangelization Rally & Fellowship night',
    startDate: DateTime(2026, 3, 14),
    endDate: DateTime(2026, 3, 14),
    locationName: "St. Michael's Hall",
    address: "Incarnation Catholic Church, 8220 W Hillsborough Ave, Tampa, FL 33615",
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
    try {
      final snapshot = await _firestore
          .collection(_eventsCollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return EventModel.fromFirestore(snapshot.docs.first);
      }
    } catch (_) {
      if (kDebugMode) {
        return _marchCluster2026Fallback;
      }
      return null;
    }
    if (kDebugMode) {
      return _marchCluster2026Fallback;
    }
    return null;
  }

  /// Submit RSVP for an event.
  Future<void> submitRsvp(String eventId, EventRsvp rsvp) async {
    await _firestore
        .collection(_eventsCollection)
        .doc(eventId)
        .collection('rsvps')
        .add(rsvp.toFirestore());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../config/firestore_config.dart';
import 'event_model.dart';
import 'event_rsvp.dart';
import 'event_schedule_model.dart';

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
      final snap = await fs.collection(_eventsCollection).doc(eventId).get();
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

    // For known slugs, skip the .where() query (avoids permission/index issues
    // with the Firestore web SDK) and go directly to doc-by-ID lookup.
    if (slug == 'march-cluster-2026') {
      try {
        final byId = await getEventById('march-assembly');
        if (byId != null) return _patchEvent(byId);
      } catch (_) {}
      return _marchCluster2026Fallback;
    }
    if (slug == 'nlc' || slug == 'nlc-2026') {
      try {
        final byId = await getEventById('nlc-2026');
        if (byId != null) return byId;
      } catch (_) {}
      return _nlcFallback;
    }

    try {
      final snapshot = await fs
          .collection(_eventsCollection)
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return _patchEvent(EventModel.fromFirestore(snapshot.docs.first));
      }
    } catch (e) {
      rethrow;
    }

    return null;
  }

  static final EventModel _nlcFallback = EventModel(
    id: 'nlc-2026',
    slug: 'nlc-2026',
    name: 'National Leaders Conference 2026',
    startDate: DateTime(2026, 2, 20),
    endDate: DateTime(2026, 2, 22),
    locationName: 'Hyatt Regency Valencia | Grand Ballroom',
    address: '24500 Town Center Dr., Valencia, CA 91355',
    isActive: true,
    allowRsvp: false,
    allowCheckin: true,
    metadata: {'selfCheckinEnabled': true, 'sessionsEnabled': true},
    logoUrl: 'assets/checkin/nlc_logo.png',
    backgroundImageUrl: 'assets/images/nlc_background.png',
    backgroundPatternUrl: 'assets/checkin/mossaic.svg',
    organizationName: 'Couples for Christ',
    tag: 'National Conference',
  );

  static final EventModel _marchCluster2026Fallback = EventModel(
    id: 'march-cluster-2026',
    slug: 'march-cluster-2026',
    name:
        'MARCH CLUSTER ASSEMBLY: Central B Cluster (BBS, Tampa, Port Charlotte) — Evangelization Rally & Fellowship Night',
    startDate: DateTime(2026, 3, 14),
    endDate: DateTime(2026, 3, 14),
    locationName: "St. Michael's Hall",
    address:
        "Incarnation Catholic Church, 8220 W Hillsborough Ave, Tampa, FL 33615",
    isActive: true,
    allowRsvp: true,
    allowCheckin: true,
    metadata: {
      'rallyTime': '3:00 – 6:00 PM',
      'dinnerTime': '7:00 PM – 9:00 PM',
      'rsvpDeadline': 'March 14',
    },
    logoUrl: 'assets/images/march_assembly_logo.png',
    backgroundImageUrl: 'assets/images/march_assembly_background.png',
    backgroundPatternUrl: 'assets/checkin/mossaic.svg',
    organizationName: 'Couples for Christ',
    shortDescription:
        'Join us for an afternoon of evangelization, worship, and fellowship. '
        'The rally runs 3:00–6:00 PM; dinner and celebration 7:00–9:00 PM. '
        'RSVP by March 14.',
  );

  static final EventModel _twrSoutheastRetreatFallback = EventModel(
    id: 'twr-southeast-b-2026',
    slug: 'twr-southeast-b-2026',
    name: 'TWR Southeast – B: Theme Weekend Retreat',
    startDate: DateTime(2026, 6, 6),
    endDate: DateTime(2026, 6, 7),
    locationName: 'Florida',
    address: 'Florida',
    isActive: true,
    allowRsvp: true,
    allowCheckin: false,
    metadata: {},
    organizationName: 'Couples for Christ',
    shortDescription:
        'In the One, we are one. Join us for a powerful weekend of faith, unity, and spiritual renewal.',
    tag: 'Regional Event',
  );

  /// List upcoming events (current + future). Used by EventsIndexPage.
  Future<List<EventModel>> listUpcomingEvents() async {
    final events = <EventModel>[
      _nlcFallback,
      _marchCluster2026Fallback,
      _twrSoutheastRetreatFallback,
    ];

    // Known fallback IDs/slugs — these always use hardcoded data
    final fallbackIds = events.map((e) => e.id).toSet();
    final fallbackSlugs = events.map((e) => e.slug).toSet();

    // Try to load additional events from Firestore
    final fs = _firestore;
    if (fs != null) {
      try {
        final snap = await fs
            .collection(_eventsCollection)
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in snap.docs) {
          final event = EventModel.fromFirestore(doc);
          // Skip any Firestore event that matches a fallback by ID or slug
          if (fallbackIds.contains(event.id) ||
              fallbackSlugs.contains(event.slug) ||
              fallbackIds.contains(event.slug) ||
              fallbackSlugs.contains(event.id)) {
            continue;
          }
          events.add(event);
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final upcoming = events.where((e) => !e.endDate.isBefore(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = events.where((e) => e.endDate.isBefore(now)).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return [...upcoming, ...past];
  }

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

  // ignore: avoid_print
  static void _log(String msg) => print('[EventRepository] $msg');

  /// List sessions for an event, with [SessionSpeaker] resolved and embedded
  /// in each [EventSession] from the speakers sub-collection.
  Future<List<EventSession>> getSessions(String eventId, {String? slug}) async {
    final raw = await _getSessionsRaw(eventId, slug: slug);
    return _enrichSessionsWithSpeakers(raw, eventId, slug: slug);
  }

  /// Resolves speakers for each session and returns enriched copies.
  ///
  /// Resolution order per session:
  ///  1. speakerIds array → match by Firestore document ID
  ///  2. Speaker subcollection sessionId → match speaker.sessionId == session.id
  ///  3. Plain-text speaker name → match speaker.displayName or speaker.name
  Future<List<EventSession>> _enrichSessionsWithSpeakers(
    List<EventSession> sessions,
    String eventId, {
    String? slug,
  }) async {
    // Check if any session has a speaker to resolve (either by ID or inline name).
    final needsEnrichment = sessions.any(
      (s) => s.speakerIds.isNotEmpty || s.speaker != null,
    );
    if (!needsEnrichment) return sessions;

    final eventSpeakers = await getSpeakers(eventId, slug: slug);
    final byId = {for (final sp in eventSpeakers) sp.id: sp};
    final bySessionId = <String, EventSpeaker>{};
    final byName = <String, EventSpeaker>{};
    for (final sp in eventSpeakers) {
      if (sp.sessionId != null && sp.sessionId!.isNotEmpty) {
        bySessionId[sp.sessionId!] = sp;
      }
      // Index by displayName and name (lowercased) for plain-text matching.
      if (sp.displayName != null && sp.displayName!.isNotEmpty) {
        byName[sp.displayName!.toLowerCase()] = sp;
      }
      byName[sp.name.toLowerCase()] = sp;
    }

    return sessions.map((s) {
      // 1. Match by speakerIds array.
      if (s.speakerIds.isNotEmpty) {
        final firstId = s.speakerIds.first;
        final sp = byId[firstId];
        if (sp != null) {
          final enriched = s.withSpeaker(SessionSpeaker.fromEventSpeaker(sp));
          _log(
            'Enriched session "${s.id}" via speakerIds → ${enriched.speaker?.name}',
          );
          return enriched;
        }
      }

      // 2. Match by speaker subcollection sessionId field.
      final bySession = bySessionId[s.id];
      if (bySession != null) {
        final enriched = s.withSpeaker(
          SessionSpeaker.fromEventSpeaker(bySession),
        );
        _log(
          'Enriched session "${s.id}" via sessionId → ${enriched.speaker?.name}',
        );
        return enriched;
      }

      // 3. Match by inline plain-text speaker name.
      if (s.speaker != null && s.speaker!.name.isNotEmpty) {
        final nameKey = s.speaker!.name.toLowerCase();
        final sp = byName[nameKey];
        if (sp != null) {
          final enriched = s.withSpeaker(SessionSpeaker.fromEventSpeaker(sp));
          _log(
            'Enriched session "${s.id}" via name match → ${enriched.speaker?.name}',
          );
          return enriched;
        }
      }

      return s;
    }).toList();
  }

  /// Internal: fetches raw sessions without speaker resolution.
  Future<List<EventSession>> _getSessionsRaw(
    String eventId, {
    String? slug,
  }) async {
    _log('getSessions: eventId=$eventId slug=$slug');
    final fs = _firestore;
    if (fs == null) {
      _log('getSessions: firestore null → fallback');
      return _fallbackSessions(eventId, slug: slug);
    }
    try {
      final snap = await fs
          .collection(_eventsCollection)
          .doc(eventId)
          .collection('sessions')
          .orderBy('order')
          .get();
      _log('getSessions: Firestore returned ${snap.docs.length} docs');
      final sessions = snap.docs
          .map((d) => EventSession.fromFirestore(d.id, d.data()))
          .toList();
      if (sessions.isEmpty) {
        _log('getSessions: empty → fallback');
        return _fallbackSessions(eventId, slug: slug);
      }
      return sessions;
    } catch (e) {
      _log('getSessions: error $e → fallback');
      return _fallbackSessions(eventId, slug: slug);
    }
  }

  /// List speakers for an event (events/{eventId}/speakers), ordered by order.
  /// [slug] is the original route slug used for fallback matching.
  Future<List<EventSpeaker>> getSpeakers(String eventId, {String? slug}) async {
    _log('getSpeakers: eventId=$eventId slug=$slug');
    final fs = _firestore;
    if (fs == null) {
      _log('getSpeakers: firestore null → fallback');
      return _fallbackSpeakers(eventId, slug: slug);
    }
    try {
      final snap = await fs
          .collection(_eventsCollection)
          .doc(eventId)
          .collection('speakers')
          .orderBy('order')
          .get();
      _log('getSpeakers: Firestore returned ${snap.docs.length} docs');
      final speakers = snap.docs
          .map((d) => EventSpeaker.fromFirestore(d.id, d.data()))
          .toList();
      if (speakers.isEmpty) {
        _log('getSpeakers: empty → fallback');
        return _fallbackSpeakers(eventId, slug: slug);
      }
      return speakers;
    } catch (e) {
      _log('getSpeakers: error $e → fallback');
      return _fallbackSpeakers(eventId, slug: slug);
    }
  }

  /// Patch a Firestore event with local overrides where Firestore data is
  /// incomplete (e.g. allowCheckin not yet set, logo/background not seeded).
  static EventModel _patchEvent(EventModel e) {
    if (!_isMarchCluster(e.id) && !_isMarchCluster(e.slug)) return e;
    return EventModel(
      id: e.id,
      slug: e.slug,
      name: e.name,
      startDate: e.startDate,
      endDate: e.endDate,
      locationName: e.locationName,
      address: e.address,
      isActive: e.isActive,
      allowRsvp: e.allowRsvp,
      allowCheckin: true, // enable check-in for event detail UI
      metadata: e.metadata,
      venue: e.venue,
      isRegistered: e.isRegistered,
      registrationStatus: e.registrationStatus,
      logoUrl: e.logoUrl ?? _marchCluster2026Fallback.logoUrl,
      backgroundImageUrl:
          e.backgroundImageUrl ?? _marchCluster2026Fallback.backgroundImageUrl,
      backgroundPatternUrl:
          e.backgroundPatternUrl ??
          _marchCluster2026Fallback.backgroundPatternUrl,
      primaryColorHex: e.primaryColorHex,
      accentColorHex: e.accentColorHex,
      backgroundOverlayColorHex: e.backgroundOverlayColorHex,
      backgroundOverlayOpacity: e.backgroundOverlayOpacity,
      bannerUrl: e.bannerUrl,
      organizationName:
          e.organizationName ?? _marchCluster2026Fallback.organizationName,
      shortDescription: e.shortDescription,
      cardBackgroundColorHex: e.cardBackgroundColorHex,
      checkInButtonColorHex: e.checkInButtonColorHex,
      tag: e.tag,
    );
  }

  static bool _isMarchCluster(String id) =>
      id == 'march-cluster-2026' ||
      id == 'march-assembly' ||
      id.contains('march') ||
      id.contains('cluster') ||
      id.contains('assembly');

  // All timestamps are UTC — Firestore stores UTC; the UI converts to local.
  static List<EventSession> _fallbackSessions(String eventId, {String? slug}) {
    if (!_isMarchCluster(eventId) && !_isMarchCluster(slug ?? '')) {
      return [];
    }
    return [
      EventSession(
        id: 'main',
        name: 'Event Check-In',
        title: 'Event Check-In',
        description: 'Main event registration and check-in',
        order: 0,
        startAt: DateTime.utc(2026, 3, 14, 0, 0),
        endAt: DateTime.utc(2026, 3, 14, 23, 59, 59),
        materials: const [],
        speakerIds: const [],
      ),
      EventSession(
        id: 'arrival',
        name: 'Arrival',
        title: 'Arrival',
        description: 'Registration — QR Code print outs',
        order: 1,
        startAt: DateTime.utc(2026, 3, 14, 17, 30),
        endAt: DateTime.utc(2026, 3, 14, 17, 45),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Alvin Martinez'),
      ),
      EventSession(
        id: 'setup',
        name: 'Set Up',
        title: 'Set Up',
        description: 'CFC — Tampa Bay, Tech Set-up',
        order: 2,
        startAt: DateTime.utc(2026, 3, 14, 17, 45),
        endAt: DateTime.utc(2026, 3, 14, 19, 30),
        materials: const [],
        speakerIds: const [],
      ),
      EventSession(
        id: 'parade-cheer',
        name: 'Parade / Cheer',
        title: 'Parade / Cheer',
        description: 'Parade / Cheer by Chapter — Inside',
        order: 3,
        startAt: DateTime.utc(2026, 3, 14, 19, 30),
        endAt: DateTime.utc(2026, 3, 14, 20, 0),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(
          name: 'Bro. Ernie Angeles',
          title: 'Emcee',
        ),
      ),
      EventSession(
        id: 'gathering-song',
        name: 'Gathering Song',
        title: 'Gathering Song',
        description:
            'CFC Theme Song 2026 — In The One, We Are One. CFC Kids will use the St. John\'s Room.',
        order: 4,
        startAt: DateTime.utc(2026, 3, 14, 20, 0),
        endAt: DateTime.utc(2026, 3, 14, 20, 5),
        materials: const [],
        speakerIds: const [],
      ),
      EventSession(
        id: 'worship',
        name: 'Worship',
        title: 'Worship',
        description: 'BBS Music Ministry',
        order: 5,
        startAt: DateTime.utc(2026, 3, 14, 20, 5),
        endAt: DateTime.utc(2026, 3, 14, 20, 20),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(
          name: 'Bro. Mike Suela',
          title: 'Worship Leader',
        ),
      ),
      EventSession(
        id: 'talk-1',
        name: 'Talk 1: The Great Commission',
        title: 'Talk 1: The Great Commission',
        description:
            "The Great Commission is Jesus Christ's final command to his disciples to spread the Gospel and make disciples of all nations, recorded in Matthew 28:18-20. Key commands include going, baptizing in the name of the Trinity, and teaching obedience to his commands. It serves as a universal, ongoing mission for all Christians to share their faith.",
        order: 6,
        startAt: DateTime.utc(2026, 3, 14, 20, 20),
        endAt: DateTime.utc(2026, 3, 14, 20, 55),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Eric Zalamea'),
      ),
      EventSession(
        id: 'talk-2',
        name: 'Talk 2: Evangelization in CFC',
        title: 'Talk 2: Evangelization in CFC',
        description:
            "In CFC, we do all these different types of evangelization. But the most basic method for every CFC member to carry out Christ's Great Commission is to undertake everyday evangelization.",
        order: 7,
        startAt: DateTime.utc(2026, 3, 14, 20, 55),
        endAt: DateTime.utc(2026, 3, 14, 21, 30),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Art Barlaan'),
      ),
      EventSession(
        id: 'declaration-of-goals',
        name: 'Declaration of Goals',
        title: 'Declaration of Goals',
        description: 'By Chapter — with slides presentation',
        order: 8,
        startAt: DateTime.utc(2026, 3, 14, 21, 30),
        endAt: DateTime.utc(2026, 3, 14, 21, 50),
        materials: const [],
        speakerIds: const [],
      ),
      EventSession(
        id: 'welcoming-new-members',
        name: 'Welcoming of New CFC Members',
        title: 'Welcoming of New CFC Members',
        order: 9,
        startAt: DateTime.utc(2026, 3, 14, 21, 50),
        endAt: DateTime.utc(2026, 3, 14, 22, 0),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Francis Navales'),
      ),
      EventSession(
        id: 'prayover-installation',
        name: 'Prayover & Installation of New Leaders',
        title: 'Prayover & Installation of New Leaders',
        description:
            'March Birthday and Anniversary Celebrants, Install New Leaders',
        order: 10,
        startAt: DateTime.utc(2026, 3, 14, 22, 0),
        endAt: DateTime.utc(2026, 3, 14, 22, 10),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Ron Ares, Bro. Sam Jutba'),
      ),
      EventSession(
        id: 'closing',
        name: 'Closing Message, Closing Prayer & Closing Song',
        title: 'Closing Message, Closing Prayer & Closing Song',
        description: 'BBS Music Ministry',
        order: 11,
        startAt: DateTime.utc(2026, 3, 14, 22, 10),
        endAt: DateTime.utc(2026, 3, 14, 22, 20),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Ed Bilbao'),
      ),
      EventSession(
        id: 'fellowship',
        name: 'Fellowship',
        title: 'Fellowship',
        description: "Bro. Art's 70th Birthday with DJ",
        order: 12,
        startAt: DateTime.utc(2026, 3, 14, 22, 20),
        endAt: DateTime.utc(2026, 3, 15, 1, 0),
        materials: const [],
        speakerIds: const [],
        speaker: const SessionSpeaker(name: 'Bro. Irwin Goingo'),
      ),
    ];
  }

  static List<EventSpeaker> _fallbackSpeakers(String eventId, {String? slug}) {
    if (!_isMarchCluster(eventId) && !_isMarchCluster(slug ?? '')) {
      return [];
    }
    return const [
      EventSpeaker(
        id: 'rommel-dolar',
        name: 'Bro Rommel Dolar',
        title: 'House Hold Head',
        photoUrl: 'assets/images/speakers/rommel_dolar.png',
        order: 0,
      ),
      EventSpeaker(
        id: 'mike-suela',
        name: 'Bro. Mike Suela',
        title: 'Unit Head',
        photoUrl: 'assets/images/speakers/mike_suela.png',
        order: 1,
      ),
    ];
  }

  /// List RSVPs for an event (e.g. March Cluster). Rules allow read: if true.
  /// Merges RSVPs from the default database AND the event-hub-prod named
  /// database (which stores prod RSVPs under events/march-cluster-2026).
  Future<List<EventRsvp>> listRsvps(String eventId) async {
    final fs = _firestore;
    if (fs == null) return [];

    final seen = <String>{};
    final list = <EventRsvp>[];

    Future<void> fetchFrom(FirebaseFirestore db, String docId) async {
      try {
        final snap = await db
            .collection(_eventsCollection)
            .doc(docId)
            .collection('rsvps')
            .get();
        for (final d in snap.docs) {
          if (seen.add(d.id)) {
            list.add(EventRsvp.fromFirestore(d.id, d.data()));
          }
        }
      } catch (_) {}
    }

    // 1. Default database (events/march-assembly/rsvps).
    await fetchFrom(fs, eventId);

    // 2. event-hub-prod named database (events/march-cluster-2026/rsvps).
    try {
      final prodDb = FirebaseFirestore.instanceFor(
        app: fs.app,
        databaseId: 'event-hub-prod',
      );
      // The prod database uses march-cluster-2026 as the event doc ID.
      final prodDocId = eventId == 'march-assembly'
          ? 'march-cluster-2026'
          : eventId;
      await fetchFrom(prodDb, prodDocId);
    } catch (_) {}

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Fetch registrants from events/{eventId}/registrants collection.
  /// Returns a lightweight list of maps with name, source, createdAt, and
  /// additionalGuests count so the dashboard can merge them with RSVPs.
  Future<List<Map<String, dynamic>>> listRegistrants(String eventId) async {
    final fs = _firestore;
    if (fs == null) return [];

    final list = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> fetchFrom(FirebaseFirestore db, String docId) async {
      try {
        print('[listRegistrants] fetching events/$docId/registrants');
        final snap = await db
            .collection(_eventsCollection)
            .doc(docId)
            .collection('registrants')
            .get();
        print('[listRegistrants] got ${snap.docs.length} from $docId');
        for (final d in snap.docs) {
          if (!seen.add(d.id)) continue;
          final data = d.data();
          final profile = data['profile'] as Map<String, dynamic>? ?? {};
          final name =
              profile['name'] as String? ??
              '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'
                  .trim();
          final additional = (data['additionalGuests'] as num?)?.toInt() ?? 0;
          final additionalRegs =
              data['additionalRegistrants'] as List<dynamic>? ?? [];
          final createdAt = data['createdAt'];
          DateTime created;
          if (createdAt is Timestamp) {
            created = createdAt.toDate();
          } else {
            created = DateTime.now();
          }
          list.add({
            'id': d.id,
            'name': name,
            'source': data['source'] as String? ?? 'app',
            'service': profile['service'] as String? ?? '',
            'chapter': profile['chapter'] as String? ?? '',
            'additionalGuests': additional,
            'additionalRegistrants': additionalRegs.length,
            'createdAt': created,
            'checkedIn': data['eventAttendance'] != null,
          });
        }
      } catch (e) {
        print('[listRegistrants] ERROR for $docId: $e');
      }
    }

    await fetchFrom(fs, eventId);

    // Also check event-hub-prod named database.
    try {
      final prodDb = FirebaseFirestore.instanceFor(
        app: fs.app,
        databaseId: 'event-hub-prod',
      );
      final prodDocId = eventId == 'march-assembly'
          ? 'march-cluster-2026'
          : eventId;
      await fetchFrom(prodDb, prodDocId);
    } catch (_) {}

    list.sort(
      (a, b) =>
          (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime),
    );
    return list;
  }
}

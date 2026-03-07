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
        return _patchEvent(EventModel.fromFirestore(snapshot.docs.first));
      }
      // NLC: event doc is at events/nlc-2026; slug query may miss if slug field differs
      if (slug == 'nlc-2026') {
        final byId = await getEventById('nlc-2026');
        if (byId != null) return byId;
        return _nlcFallback;
      }
      // March Assembly: seeded as events/march-assembly with slug march-cluster-2026
      if (slug == 'march-cluster-2026') {
        final byId = await getEventById('march-assembly');
        if (byId != null) return _patchEvent(byId);
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
    logoUrl: 'assets/checkin/nlc_logo.png',
    backgroundImageUrl: 'assets/images/nlc_background.png',
    backgroundPatternUrl: 'assets/checkin/mossaic.svg',
    organizationName: 'Couples for Christ',
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

  /// Resolves the first [speakerId] for each session into a [SessionSpeaker]
  /// and returns enriched copies. Sessions without speakerIds are unchanged.
  ///
  /// Matching uses the Firestore document ID directly — no name matching.
  // TODO: If the API ever returns a speakerId field in SessionDto, wire it
  // through EventSession.fromApiJson so the API path can also resolve full
  // profiles. Currently the API only returns speaker/speakerTitle strings,
  // so sessions arriving via the API path always have speakerId == null and
  // show the lightweight bottom-sheet preview instead of navigating.
  Future<List<EventSession>> _enrichSessionsWithSpeakers(
    List<EventSession> sessions,
    String eventId, {
    String? slug,
  }) async {
    final hasAnySpeakerIds = sessions.any((s) => s.speakerIds.isNotEmpty);
    if (!hasAnySpeakerIds) return sessions;

    final eventSpeakers = await getSpeakers(eventId, slug: slug);
    final byId = {for (final sp in eventSpeakers) sp.id: sp};

    return sessions.map((s) {
      if (s.speakerIds.isEmpty) return s;
      final firstId = s.speakerIds.first;
      final sp = byId[firstId];
      if (sp == null) {
        // Speaker document ID from session does not match any loaded speaker.
        // This can happen if the speakers sub-collection is not yet seeded.
        _log('WARNING: speakerId "$firstId" not found in speakers map for session "${s.id}" — no speaker will be shown');
        return s;
      }
      final enriched = s.withSpeaker(SessionSpeaker.fromEventSpeaker(sp));
      _log('Enriched session "${s.id}" → speakerId=${enriched.speaker?.speakerId} name=${enriched.speaker?.name}');
      return enriched;
    }).toList();
  }

  /// Internal: fetches raw sessions without speaker resolution.
  Future<List<EventSession>> _getSessionsRaw(
      String eventId, {String? slug}) async {
    _log('getSessions: eventId=$eventId slug=$slug');
    // March Cluster: always use fallback for correct session names (incl. Birthdays & Anniversaries Celebration at 7 PM) and ids.
    if (_isMarchCluster(eventId) || (slug != null && _isMarchCluster(slug))) {
      _log('getSessions: March Cluster → fallback');
      return _fallbackSessions(eventId, slug: slug);
    }
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
      // Enrich speakerIds from fallback when Firestore sessions have none set.
      final hasAnySpeakerIds = sessions.any((s) => s.speakerIds.isNotEmpty);
      if (!hasAnySpeakerIds) {
        _log('getSessions: no speakerIds in Firestore docs → enriching from fallback');
        final fallback = _fallbackSessions(eventId, slug: slug);
        final fallbackById = {for (final f in fallback) f.id: f};
        return sessions.map((s) {
          final fb = fallbackById[s.id];
          if (fb != null && fb.speakerIds.isNotEmpty) {
            return EventSession(
              id: s.id,
              name: s.name,
              title: s.title,
              description: s.description,
              location: s.location,
              order: s.order,
              startAt: s.startAt,
              endAt: s.endAt,
              materials: s.materials,
              speakerIds: fb.speakerIds,
              speaker: s.speaker,
            );
          }
          return s;
        }).toList();
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
    // March Cluster: always use fallback so speaker asset paths (rommel_dolar.png, mike_suela.png) load correctly.
    if (_isMarchCluster(eventId) || (slug != null && _isMarchCluster(slug))) {
      _log('getSpeakers: March Cluster → fallback');
      return _fallbackSpeakers(eventId, slug: slug);
    }
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
          e.backgroundPatternUrl ?? _marchCluster2026Fallback.backgroundPatternUrl,
      primaryColorHex: e.primaryColorHex,
      accentColorHex: e.accentColorHex,
      backgroundOverlayColorHex: e.backgroundOverlayColorHex,
      backgroundOverlayOpacity: e.backgroundOverlayOpacity,
      bannerUrl: e.bannerUrl,
      organizationName: e.organizationName ?? _marchCluster2026Fallback.organizationName,
      shortDescription: e.shortDescription,
      cardBackgroundColorHex: e.cardBackgroundColorHex,
      checkInButtonColorHex: e.checkInButtonColorHex,
    );
  }

  static bool _isMarchCluster(String id) =>
      id == 'march-cluster-2026' ||
      id == 'march-assembly' ||
      id.contains('march') ||
      id.contains('cluster') ||
      id.contains('assembly');

  static List<EventSession> _fallbackSessions(String eventId, {String? slug}) {
    if (!_isMarchCluster(eventId) && !_isMarchCluster(slug ?? '')) {
      return [];
    }
    return [
      EventSession(
        id: 'main-checkin',
        name: 'Main Check-In',
        order: 0,
        startAt: DateTime(2026, 3, 14, 13, 30), // 1:30 PM
        materials: const [],
        speakerIds: const [],
      ),
      EventSession(
        id: 'evangelization-rally',
        name: 'Evangelization Rally',
        order: 1,
        startAt: DateTime(2026, 3, 14, 15, 0),
        endAt: DateTime(2026, 3, 14, 18, 0),
        description: 'A Spirit-filled rally centered on evangelization and community.',
        materials: const [
          SessionMaterial(title: 'Rally Program & Reflections', url: '', type: 'pdf'),
          SessionMaterial(title: 'Small Group Discussion Guide', url: '', type: 'pdf'),
          SessionMaterial(title: 'Worship Song Sheet', url: '', type: 'pdf'),
        ],
        speakerIds: const ['rommel-dolar'],
      ),
      EventSession(
        id: 'dinner-fellowship',
        name: 'Birthdays & Anniversaries Celebration',
        order: 2,
        startAt: DateTime(2026, 3, 14, 19, 0), // 7:00 PM
        endAt: DateTime(2026, 3, 14, 21, 0),
        description: 'Dinner, fellowship, and dancing as we celebrate milestones, relationships, and the joy of community life.',
        materials: const [
          SessionMaterial(title: 'Birthdays & Anniversaries Program', url: '', type: 'pdf'),
          SessionMaterial(title: 'Fellowship Night Agenda', url: '', type: 'pdf'),
        ],
        speakerIds: const ['mike-suela'],
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
  Future<List<EventRsvp>> listRsvps(String eventId) async {
    final fs = _firestore;
    if (fs == null) return [];
    try {
      final snap = await fs
          .collection(_eventsCollection)
          .doc(eventId)
          .collection('rsvps')
          .get();
      final list = snap.docs
          .map((d) => EventRsvp.fromFirestore(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }
}

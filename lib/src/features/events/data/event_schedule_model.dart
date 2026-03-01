import 'package:cloud_firestore/cloud_firestore.dart';

/// Session material (e.g. PDF) for event schedule display.
class SessionMaterial {
  const SessionMaterial({
    required this.title,
    required this.url,
    this.type = 'pdf',
  });

  final String title;
  final String url;
  final String type;

  static SessionMaterial? fromMap(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final title = value['title'] as String?;
    final url = value['url'] as String?;
    if (title == null || url == null) return null;
    return SessionMaterial(
      title: title,
      url: url,
      type: value['type'] as String? ?? 'pdf',
    );
  }
}

/// Normalized speaker data attached directly to a session.
///
/// Used regardless of whether the session came from the API (denormalized
/// strings) or Firestore (speaker sub-document resolved by speakerId).
///
/// When [speakerId] is non-null the session card navigates to the full
/// [SpeakerDetailsPage]; when null (API-path, no document ID available)
/// the card falls back to a lightweight bottom-sheet preview instead.
class SessionSpeaker {
  const SessionSpeaker({
    required this.name,
    this.speakerId,
    this.title,
    this.imageUrl,
    this.bio,
  });

  final String name;
  /// Firestore document ID — set when resolved from events/{id}/speakers/{id}.
  /// Null on the API path where only denormalized strings are available.
  final String? speakerId;
  final String? title;
  final String? imageUrl;
  final String? bio;

  /// Create from a Firestore [EventSpeaker] sub-document, preserving its ID.
  factory SessionSpeaker.fromEventSpeaker(EventSpeaker speaker) =>
      SessionSpeaker(
        name: speaker.name,
        speakerId: speaker.id,
        title: speaker.title,
        imageUrl: speaker.photoUrl,
        bio: speaker.bio,
      );

  /// Create from denormalized API strings (SessionDto.speaker / speakerTitle).
  /// [speakerId] is always null here — no document ID is available.
  /// Returns null when [name] is absent or empty.
  static SessionSpeaker? fromApiStrings(String? name, String? title) {
    if (name == null || name.trim().isEmpty) return null;
    return SessionSpeaker(
      name: name.trim(),
      title: title?.trim().isNotEmpty == true ? title!.trim() : null,
    );
  }
}

/// Event session for schedule display (from events/{eventId}/sessions).
class EventSession {
  const EventSession({
    required this.id,
    required this.name,
    this.title,
    this.description,
    this.location,
    this.order = 0,
    this.startAt,
    this.endAt,
    this.materials = const [],
    this.speakerIds = const [],
    this.sessionCheckedIn = false,
    this.speaker,
  });

  final String id;
  final String name;
  final String? title;
  final String? description;
  final String? location;
  final int order;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<SessionMaterial> materials;
  /// Speaker document IDs for this session (from events/{eventId}/speakers).
  final List<String> speakerIds;
  /// When true, show "Checked In ✓" and disable the check-in button.
  final bool sessionCheckedIn;
  /// Resolved speaker for this session. Populated by the repository after
  /// fetching the speaker sub-document identified by [speakerIds].
  final SessionSpeaker? speaker;

  String get displayName => title ?? name;

  /// Return a copy of this session with [speaker] replaced.
  EventSession withSpeaker(SessionSpeaker? speaker) => EventSession(
        id: id,
        name: name,
        title: title,
        description: description,
        location: location,
        order: order,
        startAt: startAt,
        endAt: endAt,
        materials: materials,
        speakerIds: speakerIds,
        sessionCheckedIn: sessionCheckedIn,
        speaker: speaker,
      );

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static EventSession fromFirestore(String id, Map<String, dynamic> data) {
    final materialsRaw = data['materials'];
    final materialsList = <SessionMaterial>[];
    if (materialsRaw is List) {
      for (final item in materialsRaw) {
        final m = SessionMaterial.fromMap(item);
        if (m != null) materialsList.add(m);
      }
    }
    final speakerIdsRaw = data['speakerIds'];
    final speakerIdsList = <String>[];
    if (speakerIdsRaw is List) {
      for (final item in speakerIdsRaw) {
        if (item is String) speakerIdsList.add(item);
      }
    }
    return EventSession(
      id: id,
      name: data['name'] as String? ?? data['title'] as String? ?? '',
      title: data['title'] as String? ?? data['name'] as String?,
      description: data['description'] as String?,
      location: data['location'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
      startAt: _parseTimestamp(data['startAt']),
      endAt: _parseTimestamp(data['endAt']),
      materials: materialsList,
      speakerIds: speakerIdsList,
      sessionCheckedIn: data['sessionCheckedIn'] as bool? ?? false,
      // speaker is resolved by the repository after fetching the speaker doc
    );
  }

  /// Create from a backend API SessionDto JSON map.
  ///
  /// Maps both the denormalized [speaker]/[speakerTitle] strings and the new
  /// [speakerId] reference field introduced in the contract upgrade.
  ///
  /// When [speakerId] is present the session card navigates to the full
  /// [SpeakerDetailsPage]; when null the lightweight bottom-sheet preview
  /// is shown instead (e.g. legacy sessions with plain-text speaker only).
  static EventSession fromApiJson(String id, Map<String, dynamic> json) {
    final startRaw = json['startAt'] as String?;
    final endRaw = json['endAt'] as String?;
    final rawSpeakerName = json['speaker'] as String?;
    final rawSpeakerId = json['speakerId'] as String?;
    // ignore: avoid_print
    print('[EventSession.fromApiJson] id=$id speaker="$rawSpeakerName" speakerId="$rawSpeakerId"');

    // Build a SessionSpeaker with the document ID when the API provides it.
    // A display name is required to show a preview row at all.
    final speakerName = rawSpeakerName?.trim();
    final resolvedSpeakerId =
        rawSpeakerId?.trim().isNotEmpty == true ? rawSpeakerId!.trim() : null;
    final rawTitle = (json['speakerTitle'] as String?)?.trim();
    final resolvedTitle =
        rawTitle != null && rawTitle.isNotEmpty ? rawTitle : null;
    final speaker = (speakerName != null && speakerName.isNotEmpty)
        ? SessionSpeaker(
            name: speakerName,
            speakerId: resolvedSpeakerId,
            title: resolvedTitle,
          )
        : null;

    return EventSession(
      id: id,
      name: json['title'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      location: json['room'] as String?,
      startAt: startRaw != null ? DateTime.tryParse(startRaw) : null,
      endAt: endRaw != null ? DateTime.tryParse(endRaw) : null,
      speaker: speaker,
    );
  }
}

/// Event speaker for landing page (from events/{eventId}/speakers).
class EventSpeaker {
  const EventSpeaker({
    required this.id,
    required this.name,
    this.title,
    this.bio,
    this.photoUrl,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? title;
  final String? bio;
  final String? photoUrl;
  final int order;

  static EventSpeaker fromFirestore(String id, Map<String, dynamic> data) {
    return EventSpeaker(
      id: id,
      name: data['name'] as String? ?? '',
      title: data['title'] as String?,
      bio: data['bio'] as String?,
      photoUrl: data['photoUrl'] as String?,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }
}

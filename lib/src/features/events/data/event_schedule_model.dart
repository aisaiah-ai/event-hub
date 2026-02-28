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

  String get displayName => title ?? name;

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

import 'package:cloud_firestore/cloud_firestore.dart';

/// RSVP record stored in events/{eventId}/rsvps
class EventRsvp {
  const EventRsvp({
    required this.name,
    required this.household,
    required this.attendingRally,
    required this.attendingDinner,
    required this.attendeesCount,
    this.celebrationType,
    required this.createdAt,
    this.source,
    this.area,
    this.cfcId,
  });

  final String name;
  final String household;
  final bool attendingRally;
  final bool attendingDinner;
  final int attendeesCount;
  final String? celebrationType;
  final DateTime createdAt;
  final String? source;
  final String? area;
  final String? cfcId;

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'household': household,
    'attendingRally': attendingRally,
    'attendingDinner': attendingDinner,
    'attendeesCount': attendeesCount,
    if (celebrationType != null) 'celebrationType': celebrationType,
    'createdAt': Timestamp.fromDate(createdAt),
    if (source != null) 'source': source,
    if (area != null) 'area': area,
    if (cfcId != null) 'cfcId': cfcId,
  };

  /// Parse from Firestore document (id + data).
  static EventRsvp fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return EventRsvp(
      name: data['name'] as String? ?? '',
      household: data['household'] as String? ?? '',
      attendingRally: data['attendingRally'] as bool? ?? true,
      attendingDinner: data['attendingDinner'] as bool? ?? true,
      attendeesCount: (data['attendeesCount'] as num?)?.toInt() ?? 1,
      celebrationType: data['celebrationType'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : (DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now()),
      source: data['source'] as String?,
      area: data['area'] as String?,
      cfcId: data['cfcId'] as String?,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// A child entry in an RSVP.
class RsvpChild {
  const RsvpChild({
    required this.name,
    this.age,
    this.allergies,
  });

  final String name;
  final int? age;
  final String? allergies;

  Map<String, dynamic> toMap() => {
    'name': name,
    if (age != null) 'age': age,
    if (allergies != null && allergies!.isNotEmpty) 'allergies': allergies,
  };

  static RsvpChild fromMap(Map<String, dynamic> data) => RsvpChild(
    name: data['name'] as String? ?? '',
    age: (data['age'] as num?)?.toInt(),
    allergies: data['allergies'] as String?,
  );
}

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
    this.kids = const [],
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
  final List<RsvpChild> kids;

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
    if (kids.isNotEmpty) 'kids': kids.map((k) => k.toMap()).toList(),
  };

  /// Parse from Firestore document (id + data).
  static EventRsvp fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final kidsRaw = data['kids'];
    final kidsList = <RsvpChild>[];
    if (kidsRaw is List) {
      for (final item in kidsRaw) {
        if (item is Map<String, dynamic>) {
          kidsList.add(RsvpChild.fromMap(item));
        }
      }
    }
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
      kids: kidsList,
    );
  }
}

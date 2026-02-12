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
}

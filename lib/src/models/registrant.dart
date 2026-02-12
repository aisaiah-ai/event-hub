import 'package:cloud_firestore/cloud_firestore.dart';

import 'registrant_source.dart';

/// Event-level attendance state.
class EventAttendance {
  const EventAttendance({
    this.checkedIn = false,
    this.checkedInAt,
    this.checkedInBy,
  });

  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? checkedInBy;

  Map<String, dynamic> toJson() => {
        'checkedIn': checkedIn,
        if (checkedInAt != null) 'checkedInAt': Timestamp.fromDate(checkedInAt!),
        if (checkedInBy != null) 'checkedInBy': checkedInBy,
      };

  factory EventAttendance.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EventAttendance();
    final checkedInAt = json['checkedInAt'];
    return EventAttendance(
      checkedIn: json['checkedIn'] as bool? ?? false,
      checkedInAt: checkedInAt is Timestamp ? checkedInAt.toDate() : null,
      checkedInBy: json['checkedInBy'] as String?,
    );
  }
}

/// Registrant flags.
class RegistrantFlags {
  const RegistrantFlags({
    this.isWalkIn = false,
    this.hasValidationWarnings = false,
    this.validationWarnings = const [],
  });

  final bool isWalkIn;
  final bool hasValidationWarnings;
  final List<String> validationWarnings;

  Map<String, dynamic> toJson() => {
        'isWalkIn': isWalkIn,
        'hasValidationWarnings': hasValidationWarnings,
        if (validationWarnings.isNotEmpty) 'validationWarnings': validationWarnings,
      };

  factory RegistrantFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RegistrantFlags();
    return RegistrantFlags(
      isWalkIn: json['isWalkIn'] as bool? ?? false,
      hasValidationWarnings:
          json['hasValidationWarnings'] as bool? ?? false,
      validationWarnings: (json['validationWarnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Registrant document stored at events/{eventId}/registrants/{registrantId}
class Registrant {
  const Registrant({
    required this.id,
    this.profile = const {},
    this.answers = const {},
    this.source = RegistrantSource.registration,
    this.registrationStatus = 'registered',
    this.registeredAt,
    this.createdAt,
    this.updatedAt,
    this.eventAttendance = const EventAttendance(),
    this.flags = const RegistrantFlags(),
  });

  final String id;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> answers;
  final RegistrantSource source;
  final String registrationStatus;
  final DateTime? registeredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final EventAttendance eventAttendance;
  final RegistrantFlags flags;

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'answers': answers,
        'source': source.name,
        'registrationStatus': registrationStatus,
        if (registeredAt != null) 'registeredAt': Timestamp.fromDate(registeredAt!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        'eventAttendance': eventAttendance.toJson(),
        'flags': flags.toJson(),
      };

  factory Registrant.fromFirestore(String id, Map<String, dynamic> json) {
    final registeredAt = json['registeredAt'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    return Registrant(
      id: id,
      profile: Map<String, dynamic>.from(json['profile'] as Map? ?? {}),
      answers: Map<String, dynamic>.from(json['answers'] as Map? ?? {}),
      source: RegistrantSourceX.fromString(json['source'] as String? ?? ''),
      registrationStatus: json['registrationStatus'] as String? ?? 'registered',
      registeredAt: registeredAt is Timestamp ? registeredAt.toDate() : null,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      eventAttendance: EventAttendance.fromJson(
        json['eventAttendance'] as Map<String, dynamic>?,
      ),
      flags: RegistrantFlags.fromJson(json['flags'] as Map<String, dynamic>?),
    );
  }

  /// Combined profile + answers for form initial values.
  Map<String, dynamic> get formValues {
    final m = <String, dynamic>{};
    m.addAll(profile);
    m.addAll(answers);
    return m;
  }
}

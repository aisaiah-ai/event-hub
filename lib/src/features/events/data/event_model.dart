import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Public event model for events subdomain (event landing, RSVP, check-in).
/// Stored in Firestore collection: events/{eventId}
class EventModel {
  const EventModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.locationName,
    required this.address,
    required this.isActive,
    required this.allowRsvp,
    required this.allowCheckin,
    required this.metadata,
    this.logoUrl,
    this.backgroundImageUrl,
    this.backgroundPatternUrl,
    this.primaryColorHex,
    this.accentColorHex,
    this.organizationName,
  });

  final String id;
  final String slug;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String locationName;
  final String address;
  final bool isActive;
  final bool allowRsvp;
  final bool allowCheckin;
  final Map<String, dynamic> metadata;

  /// Logo URL or asset path (e.g. "https://..." or "assets/checkin/IntheOne.svg")
  final String? logoUrl;

  /// Full background image URL (optional)
  final String? backgroundImageUrl;

  /// Background pattern overlay URL (e.g. mosaic at low opacity)
  final String? backgroundPatternUrl;

  /// Primary theme color hex (e.g. "0E3A5D")
  final String? primaryColorHex;

  /// Accent theme color hex (e.g. "F4A340")
  final String? accentColorHex;

  /// Organization name override (e.g. "Couples for Christ")
  final String? organizationName;

  /// Resolved primary color.
  Color get primaryColor =>
      _parseColor(primaryColorHex) ?? const Color(0xFF0E3A5D);

  /// Resolved accent color.
  Color get accentColor =>
      _parseColor(accentColorHex) ?? const Color(0xFFF4A340);

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    if (clean.length != 6) return null;
    return Color(int.parse('FF$clean', radix: 16));
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final branding = data['branding'] as Map<String, dynamic>? ?? {};
    return EventModel(
      id: doc.id,
      slug: data['slug'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      startDate: _parseTimestamp(data['startDate']),
      endDate: _parseTimestamp(data['endDate']),
      locationName: data['locationName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      allowRsvp: data['allowRsvp'] as bool? ?? false,
      allowCheckin: data['allowCheckin'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      logoUrl: branding['logoUrl'] as String? ?? data['logoUrl'] as String?,
      backgroundImageUrl:
          branding['backgroundImageUrl'] as String? ??
          data['backgroundImageUrl'] as String?,
      backgroundPatternUrl:
          branding['backgroundPatternUrl'] as String? ??
          data['backgroundPatternUrl'] as String?,
      primaryColorHex:
          branding['primaryColorHex'] as String? ??
          data['primaryColorHex'] as String?,
      accentColorHex:
          branding['accentColorHex'] as String? ??
          data['accentColorHex'] as String?,
      organizationName:
          branding['organizationName'] as String? ??
          data['organizationName'] as String?,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  String get dateRangeText {
    final start = '${startDate.month}/${startDate.day}/${startDate.year}';
    final end = '${endDate.month}/${endDate.day}/${endDate.year}';
    return start == end ? start : '$start – $end';
  }

  /// Formatted date for display (e.g. "March 14, Saturday").
  String get displayDate {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final m = months[startDate.month - 1];
    final w = weekdays[startDate.weekday - 1];
    return '$m ${startDate.day}, $w';
  }

  /// Rally time range from metadata (e.g. "3:00 PM - 6:00 PM").
  String? get rallyTimeText => metadata['rallyTime'] as String?;

  /// Dinner time range from metadata (e.g. "6:00 PM - 9:00 PM").
  String? get dinnerTimeText => metadata['dinnerTime'] as String?;

  /// RSVP deadline from metadata (e.g. "March 10").
  String? get rsvpDeadlineText => metadata['rsvpDeadline'] as String?;

  /// Self-check-in enabled (public QR/search/manual at venue).
  bool get selfCheckinEnabled =>
      metadata['selfCheckinEnabled'] as bool? ?? allowCheckin;

  /// Multiple sessions for check-in (e.g. Day 1, Day 2).
  bool get sessionsEnabled => metadata['sessionsEnabled'] as bool? ?? false;
}

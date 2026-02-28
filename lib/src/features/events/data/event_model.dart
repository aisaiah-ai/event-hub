import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'venue_model.dart';

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
    this.venue,
    this.isRegistered,
    this.registrationStatus,
    this.logoUrl,
    this.backgroundImageUrl,
    this.bannerUrl,
    this.backgroundPatternUrl,
    this.primaryColorHex,
    this.accentColorHex,
    this.backgroundOverlayColorHex,
    this.backgroundOverlayOpacity,
    this.organizationName,
    this.shortDescription,
    this.cardBackgroundColorHex,
    this.checkInButtonColorHex,
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

  /// Structured venue (name, street, city, state, zip). When null, use [locationName] and [address].
  final Venue? venue;

  /// Whether the current user is registered for this event (from registration API / context).
  final bool? isRegistered;

  /// Registration status when applicable (e.g. "pending", "approved").
  final String? registrationStatus;

  /// Logo URL or asset path (e.g. "https://..." or "assets/checkin/empower.png")
  final String? logoUrl;

  /// Logo to display: for March Assembly always use bundled asset so it shows reliably.
  String? get effectiveLogoUrl {
    if (slug == 'march-cluster-2026' &&
        (logoUrl == null ||
            logoUrl!.isEmpty ||
            logoUrl!.contains('placehold') ||
            !logoUrl!.startsWith('assets/'))) {
      return 'assets/images/march_assembly_logo.png';
    }
    return logoUrl;
  }

  /// Full background image URL (optional)
  final String? backgroundImageUrl;

  /// Banner image URL shown at top of event page (optional, separate from background)
  final String? bannerUrl;

  /// Background pattern overlay URL (e.g. mosaic at low opacity)
  final String? backgroundPatternUrl;

  /// Primary theme color hex (e.g. "0E3A5D")
  final String? primaryColorHex;

  /// Accent theme color hex (e.g. "F4A340")
  final String? accentColorHex;

  /// Background overlay tint color hex (defaults to black)
  final String? backgroundOverlayColorHex;

  /// Background overlay opacity 0–1 (defaults to 0.55)
  final double? backgroundOverlayOpacity;

  /// Organization name override (e.g. "Couples for Christ")
  final String? organizationName;

  /// Short event description for the detail page (optional).
  final String? shortDescription;

  /// Card background color hex for branded cards (e.g. "141420").
  final String? cardBackgroundColorHex;

  /// Check-in button background color hex (e.g. "3E7D4C").
  final String? checkInButtonColorHex;

  /// Resolved primary color.
  Color get primaryColor =>
      _parseColor(primaryColorHex) ?? const Color(0xFF0E3A5D);

  /// Resolved accent color.
  Color get accentColor =>
      _parseColor(accentColorHex) ?? const Color(0xFFF4A340);

  /// Resolved background overlay tint (defaults to black).
  Color get backgroundOverlayColor =>
      _parseColor(backgroundOverlayColorHex) ?? const Color(0xFF000000);

  /// Resolved background overlay opacity 0–1 (defaults to 0.55).
  double get effectiveOverlayOpacity => backgroundOverlayOpacity ?? 0.55;

  /// Resolved card background (defaults to dark card #141420).
  Color get cardBackgroundColor =>
      _parseColor(cardBackgroundColorHex) ?? const Color(0xFF141420);

  /// Resolved check-in button color (defaults to green #3E7D4C).
  Color get checkInButtonColor =>
      _parseColor(checkInButtonColorHex) ?? const Color(0xFF3E7D4C);

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    if (clean.length != 6) return null;
    return Color(int.parse('FF$clean', radix: 16));
  }

  /// Effective venue for display and maps: [venue] if set, else derived from [locationName] and [address].
  Venue get effectiveVenue {
    if (venue != null) return venue!;
    return Venue(
      name: locationName,
      street: address,
      city: '',
      state: '',
      zip: '',
    );
  }

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final branding = data['branding'] as Map<String, dynamic>? ?? {};
    final locationName = data['locationName'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    final venueRaw = data['venue'];
    Venue? venue;
    if (venueRaw is Map<String, dynamic>) {
      venue = Venue.fromMap(venueRaw);
    } else if (venueRaw is String && venueRaw.isNotEmpty) {
      venue = Venue(name: venueRaw, street: address, city: '', state: '', zip: '');
    }
    if (venue == null && (locationName.isNotEmpty || address.isNotEmpty)) {
      venue = Venue(name: locationName, street: address, city: '', state: '', zip: '');
    }
    return EventModel(
      id: doc.id,
      slug: data['slug'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      startDate: _parseTimestamp(data['startDate']),
      endDate: _parseTimestamp(data['endDate']),
      locationName: locationName,
      address: address,
      isActive: data['isActive'] as bool? ?? false,
      allowRsvp: data['allowRsvp'] as bool? ?? false,
      allowCheckin: data['allowCheckin'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      venue: venue,
      isRegistered: data['isRegistered'] as bool?,
      registrationStatus: data['registrationStatus'] as String?,
      logoUrl: branding['logoUrl'] as String? ?? data['logoUrl'] as String?,
      backgroundImageUrl:
          branding['backgroundUrl'] as String? ??
          branding['backgroundImageUrl'] as String? ??
          data['backgroundImageUrl'] as String?,
      bannerUrl:
          branding['bannerUrl'] as String? ?? data['bannerUrl'] as String?,
      backgroundPatternUrl:
          branding['backgroundPatternUrl'] as String? ??
          data['backgroundPatternUrl'] as String?,
      primaryColorHex:
          branding['primaryColor'] as String? ??
          branding['primaryColorHex'] as String? ??
          data['primaryColorHex'] as String?,
      accentColorHex:
          branding['accentColor'] as String? ??
          branding['accentColorHex'] as String? ??
          data['accentColorHex'] as String?,
      backgroundOverlayColorHex:
          branding['backgroundOverlayColor'] as String? ??
          data['backgroundOverlayColor'] as String?,
      backgroundOverlayOpacity:
          (branding['backgroundOverlayOpacity'] as num?)?.toDouble() ??
          (data['backgroundOverlayOpacity'] as num?)?.toDouble(),
      organizationName:
          branding['organizationName'] as String? ??
          data['organizationName'] as String?,
      shortDescription: data['shortDescription'] as String?,
      cardBackgroundColorHex:
          branding['cardBackgroundColor'] as String? ??
          branding['cardBackgroundColorHex'] as String? ??
          data['cardBackgroundColorHex'] as String?,
      checkInButtonColorHex:
          branding['checkInButtonColor'] as String? ??
          branding['checkInButtonColorHex'] as String? ??
          data['checkInButtonColorHex'] as String?,
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

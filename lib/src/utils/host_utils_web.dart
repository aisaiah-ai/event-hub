// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// True when host is rsvp.aisaiah.org (short RSVP URL).
/// Used for ROUTING only — NOT for Firebase/ENV selection.
/// Environment is controlled exclusively by --dart-define=ENV.
bool get isRsvpSubdomain =>
    html.window.location.hostname == 'rsvp.aisaiah.org';

/// True when host is nlc.aisaiah.org (NLC check-in session picker).
bool get isNlcSubdomain =>
    html.window.location.hostname == 'nlc.aisaiah.org';

/// True when NLC session picker should be the default (nlc.aisaiah.org or localhost).
bool get isNlcLanding =>
    isNlcSubdomain ||
    html.window.location.hostname == 'localhost' ||
    html.window.location.hostname == '127.0.0.1';

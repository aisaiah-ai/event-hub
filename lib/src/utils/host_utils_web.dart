// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// True when host is rsvp.aisaiah.org (short RSVP URL).
bool get isRsvpSubdomain =>
    html.window.location.hostname == 'rsvp.aisaiah.org';

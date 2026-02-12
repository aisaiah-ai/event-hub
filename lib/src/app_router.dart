import 'package:go_router/go_router.dart';

import 'features/checkin/checkin_screen.dart';
import 'features/events/presentation/event_checkin_entry_page.dart';
import 'features/events/presentation/event_landing_page.dart';
import 'features/events/presentation/event_rsvp_page.dart';
import 'features/events/presentation/events_index_page.dart';
import 'screens/admin/import_registrants_screen.dart';
import 'screens/admin/manual_checkin_screen.dart';
import 'screens/admin/registrant_edit_screen.dart';
import 'screens/admin/registrant_new_screen.dart';
import 'screens/admin/schema_editor_screen.dart';
import 'models/role_override.dart';
import 'screens/home_screen.dart';

/// Event ID for development. In production, derive from route or auth.
const defaultEventId = 'nlc-2025';

/// Default session for check-in when none specified.
const defaultSessionId = 'session-1';

DateTime? _parseEventDate(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/events',
    routes: [
      // Root redirects to events
      GoRoute(path: '/', redirect: (context, state) => '/events'),
      // Events subdomain routes
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsIndexPage(),
      ),
      GoRoute(
        path: '/events/:eventSlug',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          final queryParams = state.uri.queryParameters;
          return EventLandingPage(eventSlug: slug, queryParams: queryParams);
        },
      ),
      GoRoute(
        path: '/events/:eventSlug/rsvp',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          final source = state.uri.queryParameters['rsvpSource'];
          return EventRsvpPage(eventSlug: slug, source: source);
        },
      ),
      GoRoute(
        path: '/events/:eventSlug/checkin',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          return EventCheckinEntryPage(eventSlug: slug);
        },
      ),
      // Staff check-in portal (checkin.aisaiah.org)
      GoRoute(
        path: '/checkin',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          final sessionId =
              state.uri.queryParameters['sessionId'] ?? defaultSessionId;
          return CheckinScreen(
            eventId: eventId,
            sessionId: sessionId,
            checkedInBy: 'admin',
            eventTitle: state.uri.queryParameters['eventTitle'],
            eventVenue: state.uri.queryParameters['eventVenue'],
            eventDate: _parseEventDate(state.uri.queryParameters['eventDate']),
          );
        },
      ),
      // Admin dashboard
      GoRoute(
        path: '/admin',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          return HomeScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/admin/schema/registration',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          return SchemaEditorScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/admin/registrants/new',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          return RegistrantNewScreen(eventId: eventId, role: UserRole.admin);
        },
      ),
      GoRoute(
        path: '/admin/registrants/:id/edit',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          final id = state.pathParameters['id'] ?? '';
          return RegistrantEditScreen(eventId: eventId, registrantId: id);
        },
      ),
      GoRoute(
        path: '/admin/sessions/:sessionId/manual-checkin',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return ManualCheckinScreen(
            eventId: eventId,
            sessionId: sessionId,
            checkedInBy: 'admin',
          );
        },
      ),
      GoRoute(
        path: '/admin/import/registrants',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          return ImportRegistrantsScreen(eventId: eventId);
        },
      ),
    ],
  );
}

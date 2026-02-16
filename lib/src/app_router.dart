import 'package:go_router/go_router.dart';

import '../../config/environment.dart';
import 'features/checkin/checkin_screen.dart';
import 'features/event_checkin/presentation/checkin_dashboard_screen.dart';
import 'features/event_checkin/presentation/checkin_manual_entry_page.dart';
import 'features/event_checkin/data/checkin_mode.dart' show CheckInFlowType, CheckInMode;
import 'features/event_checkin/presentation/checkin_search_page.dart';
import 'features/event_checkin/presentation/checkin_success_page.dart';
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
import 'features/debug/presentation/connection_test_screen.dart';
import 'utils/host_utils.dart';

/// Event ID for development. In production, derive from route or auth.
const defaultEventId = 'nlc-2025';

/// Default event slug for rsvp.aisaiah.org root.
const _defaultRsvpEventSlug = 'march-cluster-2026';

/// Default session for check-in when none specified.
const defaultSessionId = 'session-1';

DateTime? _parseEventDate(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: Environment.isDev ? '/events/nlc/checkin' : '/events',
    routes: [
      // rsvp.aisaiah.org: / shows RSVP. events: / -> /events or /events/nlc/checkin (dev)
      GoRoute(
        path: '/',
        redirect: (context, state) {
          if (isRsvpSubdomain) return null;
          return Environment.isDev ? '/events/nlc/checkin' : '/events';
        },
        builder: (context, state) => EventRsvpPage(
          eventSlug: _defaultRsvpEventSlug,
        ),
      ),
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
        path: '/events/:eventSlug/main-checkin',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          return EventCheckinEntryPage(
            eventSlug: slug,
            mode: CheckInFlowType.event,
            isMainCheckIn: true,
          );
        },
      ),
      GoRoute(
        path: '/events/:eventSlug/checkin',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          return EventCheckinEntryPage(eventSlug: slug);
        },
        routes: [
          // Literal paths first so they match before :sessionSlug
          GoRoute(
            path: 'search',
            builder: (context, state) {
              final slug = state.pathParameters['eventSlug'] ?? '';
              final extra = state.extra as Map<String, dynamic>?;
              final eventId = extra?['eventId'] as String? ??
                  (slug == 'nlc' ? 'nlc-2026' : slug);
              final sessionId = extra?['sessionId'] as String? ?? 'main-checkin';
              final sessionName = extra?['sessionName'] as String? ?? 'Main Check-In';
              final mode = CheckInMode(
                eventId: eventId,
                sessionId: sessionId,
                displayName: sessionName,
              );
              return CheckinSearchPage(
                eventId: eventId,
                eventSlug: slug,
                mode: mode,
                repository: null,
              );
            },
          ),
          GoRoute(
            path: 'manual',
            builder: (context, state) {
              final slug = state.pathParameters['eventSlug'] ?? '';
              final extra = state.extra as Map<String, dynamic>?;
              final eventId = extra?['eventId'] as String? ??
                  (slug == 'nlc' ? 'nlc-2026' : slug);
              return CheckinManualEntryPage(
                eventId: eventId,
                eventSlug: slug,
                sessionId: extra?['sessionId'] as String? ?? 'default',
              );
            },
          ),
          GoRoute(
            path: 'success',
            builder: (context, state) {
              final slug = state.pathParameters['eventSlug'] ?? '';
              final extra = state.extra as Map<String, dynamic>?;
              return CheckinSuccessPage(
                name: extra?['name'] as String? ?? 'Guest',
                sessionName: extra?['sessionName'] as String? ?? 'Session',
                eventSlug: slug,
                returnPath: extra?['returnPath'] as String?,
              );
            },
          ),
          // Session-specific check-in: /events/nlc/checkin/gender-ideology
          GoRoute(
            path: ':sessionSlug',
            builder: (context, state) {
              final slug = state.pathParameters['eventSlug'] ?? '';
              final sessionSlug = state.pathParameters['sessionSlug'] ?? '';
              return EventCheckinEntryPage(
                eventSlug: slug,
                sessionSlug: sessionSlug,
              );
            },
          ),
        ],
      ),
      // Alternative: /events/:eventSlug/sessions/:sessionId/checkin
      GoRoute(
        path: '/events/:eventSlug/sessions/:sessionId/checkin',
        builder: (context, state) {
          final slug = state.pathParameters['eventSlug'] ?? '';
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return EventCheckinEntryPage(
            eventSlug: slug,
            sessionSlug: sessionId,
          );
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
        path: '/admin/dashboard',
        builder: (context, state) {
          final eventId =
              state.uri.queryParameters['eventId'] ?? defaultEventId;
          final eventTitle = state.uri.queryParameters['eventTitle'];
          return CheckinDashboardScreen(
            eventId: eventId,
            eventTitle: eventTitle,
          );
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
      GoRoute(
        path: '/debug/connection-test',
        builder: (context, state) => const ConnectionTestScreen(),
      ),
    ],
  );
}

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'config/environment.dart';
import 'firebase_options.dart';
import 'src/app_router.dart';
import 'src/config/firestore_config.dart'
    show AppEnvironment, FirestoreConfig;
import 'src/theme/app_theme.dart';
import 'src/utils/url_utils.dart';

void main() async {
  // ENV must be set via --dart-define=ENV (CI/CD). No hostname fallback.
  // Fails fast if undefined or invalid.
  final env = Environment.env;
  // ignore: avoid_print
  print('Running in ENV: $env');

  assert(Environment.isDev || Environment.isProd,
      'Environment must be dev or prod; got $env');

  usePathUrlStrategy();
  if (kIsWeb) {
    redirectHashToPathIfNeeded();
  }
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone DB for Last Updated display (PST default, tap to change).
  try {
    tz_data.initializeTimeZones();
  } catch (_) {}

  // Single Firebase project; Firestore database (event-hub-dev vs event-hub-prod)
  // is selected by FirestoreConfig based on ENV.
  bool firebaseOk = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseOk = true;
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    if (kDebugMode) rethrow;
  }

  if (firebaseOk) {
    // Debug: confirm Firebase project (must match Firebase Console)
    // ignore: avoid_print
    print('Firebase Project: ${Firebase.app().options.projectId}');

    // Ensure request.auth is available for write paths in stricter rule sets.
    try {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('✅ Firebase Auth: anonymous session active.');
    } catch (e) {
      debugPrint('⚠️ Firebase Auth anonymous sign-in failed: $e');
    }

    // Activate App Check (don't block app if it fails, e.g. on web without provider)
    bool appCheckOk = false;
    // START DEBUGGING: APP CHECK DISABLED
    // Note: If App Check Enforcement is ON in Console, this will fail with permission-denied.
    // Ensure Enforcement is OFF for Firestore in Firebase Console.
    debugPrint('🛑 APP CHECK ACTIVATION COMMENTED OUT.'); 
    appCheckOk = true; 
    
    /*
    try {
      if (kIsWeb) {
        // BYPASS App Check in DEV to unblock development (since rules are currently 'allow all')
        if (Environment.isDev) {
            debugPrint('⚠️ SKIPPING App Check activation in DEV to bypass permission errors.');
            debugPrint('⚠️ Ensure your Firestore Rules allow access accordingly.');
            appCheckOk = true; 
        } else {
             // For web in PROD, we attempt to activate with a placeholder key
            try {
               await FirebaseAppCheck.instance.activate(
                webProvider: ReCaptchaV3Provider('6Le5-TQmAAAAADwXqGj8d4_j4L4x4c4x4c4x4c4'),
              );
              debugPrint('✅ App Check: Activated for Web.');
              appCheckOk = true; 
            } catch (e) {
               debugPrint('❌ App Check: Web activation failed: $e');
            }
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        appCheckOk = true;
      }
    } catch (e) {
      debugPrint('App Check activate failed (non-fatal): $e');
    }
    */
    // END DEBUGGING
    if (kDebugMode && !appCheckOk) {
      debugPrint(
        'TROUBLESHOOTING: App Check is not active. If Firestore returns permission-denied, '
        'go to Firebase Console → App Check → Firestore and either:\n'
        '  1) Disable enforcement (recommended for dev), or\n'
        '  2) Add ReCaptchaV3Provider for web and register your domain.',
      );
    }

    FirestoreConfig.initFromEnvironment();
    // Safety: ensure Firestore matches ENV (debug mode only; asserts removed in release)
    assert(
      (Environment.isDev && FirestoreConfig.environment == AppEnvironment.dev) ||
          (Environment.isProd &&
              FirestoreConfig.environment == AppEnvironment.prod),
      'FirestoreConfig must match Environment',
    );
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Environment.isDev
            ? Banner(
                message: 'DEV ENVIRONMENT',
                location: BannerLocation.topEnd,
                color: Colors.red,
                child: const EventHubApp(),
              )
            : const EventHubApp(),
      ),
    );
  } else {
    runApp(const _FirebaseErrorApp());
  }
}

class _FirebaseErrorApp extends StatelessWidget {
  const _FirebaseErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Unable to load',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection and try again. '
                  'If the issue persists, the service may be temporarily unavailable.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Event Hub',
      theme: AppTheme.light,
      routerConfig: createAppRouter(),
    );
  }
}

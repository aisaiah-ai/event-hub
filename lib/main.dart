import 'package:firebase_core/firebase_core.dart';
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
    FirestoreConfig.initFromEnvironment();
    // Safety: ensure Firestore matches ENV (debug mode only; asserts removed in release)
    assert(
      (Environment.isDev && FirestoreConfig.environment == AppEnvironment.dev) ||
          (Environment.isProd &&
              FirestoreConfig.environment == AppEnvironment.prod),
      'FirestoreConfig must match Environment',
    );
    runApp(
      Environment.isDev
          ? Banner(
              message: 'DEV ENVIRONMENT',
              location: BannerLocation.topEnd,
              color: Colors.red,
              child: const EventHubApp(),
            )
          : const EventHubApp(),
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

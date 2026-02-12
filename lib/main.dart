import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'src/app_router.dart';
import 'src/config/firestore_config.dart';
import 'src/theme/app_theme.dart';
import 'src/utils/url_utils.dart';

void main() async {
  usePathUrlStrategy();
  if (kIsWeb) {
    redirectHashToPathIfNeeded();
  }
  WidgetsFlutterBinding.ensureInitialized();
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
    FirestoreConfig.initFromDartDefine();
    runApp(const EventHubApp());
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

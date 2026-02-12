import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app_router.dart';
import 'src/config/firestore_config.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
    // Don't rethrow: let app load; Firestore calls may fail but we avoid blank screen
    if (kDebugMode) rethrow;
  }
  // Use dev database in debug mode, prod otherwise
  FirestoreConfig.init(kDebugMode ? AppEnvironment.dev : AppEnvironment.prod);
  runApp(const EventHubApp());
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

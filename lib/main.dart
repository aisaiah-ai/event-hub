import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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
    // Run `flutterfire configure` to generate Firebase config
    debugPrint('Firebase init failed: $e');
    rethrow;
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

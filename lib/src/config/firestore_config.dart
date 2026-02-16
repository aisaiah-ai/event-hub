import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../config/environment.dart';

// ignore: avoid_print
void _log(String msg) => print('[FirestoreConfig] $msg');

/// Uses the default Firestore database.
enum AppEnvironment { dev, prod }

/// Central Firestore configuration. Uses the default Firestore database.
class FirestoreConfig {
  FirestoreConfig._();

  static FirebaseFirestore? _instance;
  static AppEnvironment _env = AppEnvironment.prod;

  /// Current environment.
  static AppEnvironment get environment => _env;

  /// Default Firestore database.
  static String get databaseId => '(default)';

  /// Whether Firestore is available (named database exists).
  static bool get isAvailable => _instance != null;

  /// Firestore instance for the default database.
  static FirebaseFirestore? get instanceOrNull {
    if (_instance != null) return _instance;
    try {
      final app = Firebase.app();
      _instance = FirebaseFirestore.instanceFor(app: app);
      _log('Connected: project=${app.options.projectId}, database=$databaseId');
      return _instance;
    } catch (e) {
      _log('Init failed: $e');
      return null;
    }
  }

  /// Firestore instance for the default database. Throws if not available.
  static FirebaseFirestore get instance => instanceOrNull!;

  /// Initialize config from Environment. Call from main() before runApp.
  /// Uses --dart-define=ENV (dev|prod). Defaults to prod when not set.
  static void initFromEnvironment() {
    init(Environment.isDev ? AppEnvironment.dev : AppEnvironment.prod);
  }

  static void init(AppEnvironment env) {
    _env = env;
    _instance = null; // Reset so next [instanceOrNull] uses new databaseId
    // Explicit debug log to verify which database we are targeting
    _log('Initializing config for ENV: ${env.name.toUpperCase()}');
    _log('Targeting Database ID: $databaseId');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Environment: dev uses event-hub-dev, prod uses event-hub-prod.
enum AppEnvironment { dev, prod }

/// Central Firestore configuration. Use [databaseId] when creating
/// FirebaseFirestore.instanceFor() for the named database.
class FirestoreConfig {
  FirestoreConfig._();

  static FirebaseFirestore? _instance;
  static AppEnvironment _env = AppEnvironment.prod;

  /// Current environment.
  static AppEnvironment get environment => _env;

  /// Database ID: 'event-hub-dev' for dev, 'event-hub-prod' for prod.
  static String get databaseId =>
      _env == AppEnvironment.dev ? 'event-hub-dev' : 'event-hub-prod';

  /// Whether Firestore is available (named database exists).
  static bool get isAvailable => _instance != null;

  /// Firestore instance, or null if named database doesn't exist yet.
  static FirebaseFirestore? get instanceOrNull {
    if (_instance != null) return _instance;
    try {
      _instance = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// Firestore instance. Throws if not available.
  static FirebaseFirestore get instance => instanceOrNull!;

  /// Initialize config. Call from main() before runApp.
  static void init(AppEnvironment env) {
    _env = env;
    _instance = null; // Reset so next [instanceOrNull] uses new databaseId
  }

  /// Initialize from dart-define. E.g. flutter build web --dart-define=ENV=dev
  /// Defaults to dev when building (safer for testing), prod when not set.
  static void initFromDartDefine() {
    const env = String.fromEnvironment('ENV', defaultValue: '');
    if (env.isNotEmpty) {
      init(env == 'dev' ? AppEnvironment.dev : AppEnvironment.prod);
    } else {
      init(kDebugMode ? AppEnvironment.dev : AppEnvironment.prod);
    }
  }
}

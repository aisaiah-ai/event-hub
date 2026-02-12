import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Environment: dev uses event-hub-dev, prod uses (default).
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

  /// Firestore instance for the current environment.
  static FirebaseFirestore get instance {
    if (_instance != null) return _instance!;
    _instance = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );
    return _instance!;
  }

  /// Initialize config. Call from main() before runApp.
  static void init(AppEnvironment env) {
    _env = env;
    _instance = null; // Reset so next [instance] uses new databaseId
  }

  /// Initialize from dart-define. E.g. flutter run --dart-define=ENV=dev
  static void initFromDartDefine() {
    const env = String.fromEnvironment('ENV', defaultValue: 'prod');
    init(env == 'dev' ? AppEnvironment.dev : AppEnvironment.prod);
  }
}

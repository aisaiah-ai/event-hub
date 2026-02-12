/// Environment controlled ONLY by --dart-define=ENV=dev|prod.
/// No hostname-based detection. No silent fallback.
///
/// Fails fast on startup if ENV is undefined or invalid.
class Environment {
  static const String _raw =
      String.fromEnvironment('ENV', defaultValue: '');

  /// Validated environment. Throws if undefined or invalid.
  static String get env {
    if (_raw.isEmpty) {
      throw StateError(
        'ENV not defined. Use --dart-define=ENV=dev or --dart-define=ENV=prod',
      );
    }
    if (_raw != 'dev' && _raw != 'prod') {
      throw StateError('ENV must be "dev" or "prod", got: "$_raw"');
    }
    return _raw;
  }

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';
}

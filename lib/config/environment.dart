/// Environment controlled by --dart-define=ENV=dev|prod.
/// Defaults to 'dev' when not set (local development).
/// CI/CD should always pass ENV explicitly.
class Environment {
  static const String _raw =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  /// Validated environment. Defaults to 'dev' when not set.
  static String get env {
    final value = _raw.isEmpty ? 'dev' : _raw;
    if (value != 'dev' && value != 'prod') {
      throw StateError('ENV must be "dev" or "prod", got: "$value"');
    }
    return value;
  }

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';
}

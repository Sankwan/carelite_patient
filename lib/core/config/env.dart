/// Environment configuration, injected at build time via --dart-define.
///
/// Run with, e.g.:
///   flutter run \
///     --dart-define=DJANGO_API_BASE_URL=http://10.0.2.2:8000
///
/// (Android emulator reaches the host as 10.0.2.2, not 127.0.0.1.)
///
/// Never read secrets from a checked-in file. Only the API base URL belongs
/// here — the JWT pair is issued at runtime and kept in secure storage, not
/// in build config.
abstract final class Env {
  /// Root of the Django REST API, without a trailing slash.
  static const String djangoApiBaseUrl = String.fromEnvironment(
    'DJANGO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static bool get isConfigured => djangoApiBaseUrl.isNotEmpty;
}

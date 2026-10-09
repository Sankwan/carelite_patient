import 'package:flutter/foundation.dart';

/// Environment configuration, injected at build time via --dart-define.
///
/// Run with, e.g.:
///   flutter run --dart-define=DJANGO_API_BASE_URL=https://api.example.com
///
/// Never read secrets from a checked-in file. Only the API base URL belongs
/// here — the JWT pair is issued at runtime and kept in secure storage, not
/// in build config.
abstract final class Env {
  static const String _configured =
      String.fromEnvironment('DJANGO_API_BASE_URL');

  /// Root of the Django REST API, without a trailing slash.
  ///
  /// With no `--dart-define`, this points at a server on the developer's
  /// own machine. That address differs by where the app runs: a browser
  /// shares the machine's `localhost`, while the Android emulator reaches
  /// the host as `10.0.2.2`.
  static String get djangoApiBaseUrl {
    if (_configured.isNotEmpty) return _configured;
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  static bool get isConfigured => djangoApiBaseUrl.isNotEmpty;
}

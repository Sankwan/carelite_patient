import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over [SharedPreferences] so features depend on named,
/// typed accessors instead of raw string keys scattered across the app —
/// the same reason [ApiClient] wraps the Django HTTP client.
///
/// Deliberately not a repository: these are device-local UI flags, not
/// domain data, so they never need a `Result<T>`/`Failure` round trip.
/// Anything that must survive a reinstall belongs in Postgres instead.
class AppPreferences {
  const AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _kHasCompletedOnboarding = 'has_completed_onboarding';
  static const String _kHasSeenLocationPrompt = 'has_seen_location_prompt';

  /// Resolved once in `bootstrap()` so callers never await a plugin channel
  /// mid-build (a `redirect` callback cannot await).
  static Future<AppPreferences> resolve() async {
    return AppPreferences(await SharedPreferences.getInstance());
  }

  bool get hasCompletedOnboarding => _prefs.getBool(_kHasCompletedOnboarding) ?? false;

  Future<void> setHasCompletedOnboarding({required bool value}) {
    return _prefs.setBool(_kHasCompletedOnboarding, value);
  }

  /// Distinct from "permission granted": the OS owns permission state, this
  /// only records that we already asked once, so a user who tapped "Maybe
  /// Later" is not re-prompted on every launch.
  bool get hasSeenLocationPrompt => _prefs.getBool(_kHasSeenLocationPrompt) ?? false;

  Future<void> setHasSeenLocationPrompt({required bool value}) {
    return _prefs.setBool(_kHasSeenLocationPrompt, value);
  }
}

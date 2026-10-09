import '../../../core/network/failure.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/utils/result.dart';

/// Abstract so the Bloc depends on this contract rather than on
/// `shared_preferences` directly — mirrors [AuthRepository]'s shape and
/// keeps the Bloc test free of a plugin channel.
abstract class OnboardingRepository {
  bool get hasCompletedOnboarding;

  Future<Result<void>> completeOnboarding();
}

class PreferencesOnboardingRepository implements OnboardingRepository {
  const PreferencesOnboardingRepository(this._prefs);

  final AppPreferences _prefs;

  @override
  bool get hasCompletedOnboarding => _prefs.hasCompletedOnboarding;

  @override
  Future<Result<void>> completeOnboarding() async {
    try {
      await _prefs.setHasCompletedOnboarding(value: true);
      return const Result.ok(null);
    } catch (_) {
      // Disk write failure is recoverable: the user still proceeds, they
      // just see onboarding again next launch. Never block the funnel.
      return const Result.err(
        UnexpectedFailure('Could not save your progress, but you can continue.'),
      );
    }
  }
}

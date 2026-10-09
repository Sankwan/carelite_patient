import 'package:equatable/equatable.dart';

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Emitted when the user swipes or taps Next — keeps the pager index in
/// the Bloc so the dots, the Skip/Next affordances and the final slide's
/// CTA all read one source of truth.
final class OnboardingSlideChanged extends OnboardingEvent {
  const OnboardingSlideChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// "Skip" and finishing the last slide are the same outcome — the flag is
/// written either way, so a skipper is never re-prompted.
final class OnboardingCompleted extends OnboardingEvent {
  const OnboardingCompleted();
}

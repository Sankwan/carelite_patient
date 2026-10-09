import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/onboarding_repository.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({required OnboardingRepository onboardingRepository})
      : _onboardingRepository = onboardingRepository,
        super(const OnboardingState()) {
    on<OnboardingSlideChanged>(_onSlideChanged);
    on<OnboardingCompleted>(_onCompleted);
  }

  final OnboardingRepository _onboardingRepository;

  void _onSlideChanged(OnboardingSlideChanged event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(slideIndex: event.index));
  }

  Future<void> _onCompleted(
    OnboardingCompleted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(status: OnboardingStatus.completing, clearFailure: true));
    final result = await _onboardingRepository.completeOnboarding();
    // Both branches reach `completed`: a failed flag write is surfaced to
    // the user but must never trap them on the onboarding screen.
    result.when(
      ok: (_) => emit(state.copyWith(status: OnboardingStatus.completed)),
      err: (failure) => emit(
        state.copyWith(status: OnboardingStatus.completed, failure: failure),
      ),
    );
  }
}

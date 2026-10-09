import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/onboarding/data/onboarding_repository.dart';
import 'package:carelite_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:carelite_app/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:carelite_app/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late _MockOnboardingRepository onboardingRepository;

  setUp(() {
    onboardingRepository = _MockOnboardingRepository();
  });

  group('OnboardingBloc', () {
    blocTest<OnboardingBloc, OnboardingState>(
      'tracks the slide index as the user pages through',
      build: () => OnboardingBloc(onboardingRepository: onboardingRepository),
      act: (bloc) => bloc
        ..add(const OnboardingSlideChanged(1))
        ..add(const OnboardingSlideChanged(2)),
      expect: () => [
        const OnboardingState(slideIndex: 1),
        const OnboardingState(slideIndex: 2),
      ],
    );

    test('isLastSlide is true only on the final slide', () {
      const middle = OnboardingState(slideIndex: 1);
      const last = OnboardingState(slideIndex: OnboardingState.slideCount - 1);
      expect(middle.isLastSlide, isFalse);
      expect(last.isLastSlide, isTrue);
    });

    blocTest<OnboardingBloc, OnboardingState>(
      'emits [completing, completed] and persists the flag',
      build: () {
        when(() => onboardingRepository.completeOnboarding())
            .thenAnswer((_) async => const Result.ok(null));
        return OnboardingBloc(onboardingRepository: onboardingRepository);
      },
      act: (bloc) => bloc.add(const OnboardingCompleted()),
      expect: () => [
        const OnboardingState(status: OnboardingStatus.completing),
        const OnboardingState(status: OnboardingStatus.completed),
      ],
      verify: (_) =>
          verify(() => onboardingRepository.completeOnboarding()).called(1),
    );

    blocTest<OnboardingBloc, OnboardingState>(
      'still reaches completed when the flag write fails, surfacing the failure',
      build: () {
        when(() => onboardingRepository.completeOnboarding())
            .thenAnswer((_) async => const Result.err(UnexpectedFailure()));
        return OnboardingBloc(onboardingRepository: onboardingRepository);
      },
      act: (bloc) => bloc.add(const OnboardingCompleted()),
      expect: () => [
        const OnboardingState(status: OnboardingStatus.completing),
        // Never trap the user on onboarding just because a disk write
        // failed — they proceed, and simply see it again next launch.
        isA<OnboardingState>()
            .having((s) => s.status, 'status', OnboardingStatus.completed)
            .having((s) => s.failure, 'failure', isA<UnexpectedFailure>()),
      ],
    );
  });
}

import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';

enum OnboardingStatus { inProgress, completing, completed }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.inProgress,
    this.slideIndex = 0,
    this.failure,
  });

  /// Total slides, owned here so the pager, the dots and the "is this the
  /// last slide?" check can never disagree about the count.
  static const int slideCount = 3;

  final OnboardingStatus status;
  final int slideIndex;
  final Failure? failure;

  bool get isLastSlide => slideIndex == slideCount - 1;

  OnboardingState copyWith({
    OnboardingStatus? status,
    int? slideIndex,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      slideIndex: slideIndex ?? this.slideIndex,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, slideIndex, failure];
}

import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';

enum ChangePasswordStatus { idle, submitting, done }

final class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.idle,
    this.failure,
  });

  final ChangePasswordStatus status;
  final Failure? failure;

  ChangePasswordState copyWith({
    ChangePasswordStatus? status,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ChangePasswordState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, failure];
}

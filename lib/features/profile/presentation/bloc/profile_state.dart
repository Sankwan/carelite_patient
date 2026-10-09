import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/patient_account.dart';

enum ProfileStatus { loading, ready }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.loading,
    this.account,
    this.failure,
  });

  final ProfileStatus status;
  final PatientAccount? account;
  final Failure? failure;

  ProfileState copyWith({
    ProfileStatus? status,
    PatientAccount? account,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      account: account ?? this.account,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, account, failure];
}

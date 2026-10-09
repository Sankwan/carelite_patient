import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/patient_profile.dart';

enum ProfileSetupStatus { editing, submitting, success }

class ProfileSetupState extends Equatable {
  const ProfileSetupState({
    this.status = ProfileSetupStatus.editing,
    this.profile = const PatientProfile(),
    this.failure,
  });

  final ProfileSetupStatus status;
  final PatientProfile profile;
  final Failure? failure;

  bool get canSubmit =>
      profile.isSubmittable && status != ProfileSetupStatus.submitting;

  ProfileSetupState copyWith({
    ProfileSetupStatus? status,
    PatientProfile? profile,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ProfileSetupState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, profile, failure];
}

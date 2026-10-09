import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/profile_repository.dart';
import 'profile_setup_event.dart';
import 'profile_setup_state.dart';

class ProfileSetupBloc extends Bloc<ProfileSetupEvent, ProfileSetupState> {
  ProfileSetupBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const ProfileSetupState()) {
    on<ProfileFullNameChanged>(_onFullNameChanged);
    on<ProfileDateOfBirthChanged>(_onDateOfBirthChanged);
    on<ProfileGenderChanged>(_onGenderChanged);
    on<ProfileBloodTypeChanged>(_onBloodTypeChanged);
    on<ProfileEmergencyContactChanged>(_onEmergencyContactChanged);
    on<ProfileSubmitted>(_onSubmitted);
  }

  final ProfileRepository _profileRepository;

  void _onFullNameChanged(
    ProfileFullNameChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(state.copyWith(profile: state.profile.copyWith(fullName: event.fullName)));
  }

  void _onDateOfBirthChanged(
    ProfileDateOfBirthChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(state.copyWith(
      profile: state.profile.copyWith(dateOfBirth: event.dateOfBirth),
    ));
  }

  void _onGenderChanged(
    ProfileGenderChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(state.copyWith(profile: state.profile.copyWith(gender: event.gender)));
  }

  void _onBloodTypeChanged(
    ProfileBloodTypeChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(state.copyWith(
      profile: state.profile.copyWith(bloodType: event.bloodType),
    ));
  }

  void _onEmergencyContactChanged(
    ProfileEmergencyContactChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(state.copyWith(
      profile: state.profile.copyWith(
        emergencyContact: state.profile.emergencyContact.copyWith(
          name: event.name,
          phone: event.phone,
        ),
      ),
    ));
  }

  Future<void> _onSubmitted(
    ProfileSubmitted event,
    Emitter<ProfileSetupState> emit,
  ) async {
    // Guard in the Bloc as well as on the button: an event can arrive from
    // anywhere, and a half-filled profile must never reach the database.
    if (!state.profile.isSubmittable) return;

    emit(state.copyWith(status: ProfileSetupStatus.submitting, clearFailure: true));
    final result = await _profileRepository.saveProfile(
      userId: event.userId,
      profile: state.profile,
    );
    result.when(
      ok: (_) => emit(state.copyWith(status: ProfileSetupStatus.success)),
      err: (failure) => emit(state.copyWith(
        status: ProfileSetupStatus.editing,
        failure: failure,
      )),
    );
  }
}

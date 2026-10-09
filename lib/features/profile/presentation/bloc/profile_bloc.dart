import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/profile_repository.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileRefreshed>(_onRefreshed);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onStarted(ProfileStarted event, Emitter<ProfileState> emit) async {
    emit(state.copyWith(status: ProfileStatus.loading, clearFailure: true));
    await _load(emit);
  }

  Future<void> _onRefreshed(
    ProfileRefreshed event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(clearFailure: true));
    await _load(emit);
  }

  Future<void> _load(Emitter<ProfileState> emit) async {
    try {
      final result = await _profileRepository.fetchAccount();
      result.when(
        ok: (account) => emit(state.copyWith(
          status: ProfileStatus.ready,
          account: account,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          // ready, not a failure status: sign-out must stay reachable even
          // when the profile itself could not be loaded.
          status: ProfileStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      // The same guard HomeBloc carries — no screen may hang on a spinner.
      emit(state.copyWith(
        status: ProfileStatus.ready,
        failure: UnexpectedFailure(
          'Could not load your profile (${e.runtimeType}).',
        ),
      ));
    }
  }
}

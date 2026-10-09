import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../data/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc({
    required LocationRepository locationRepository,
    required AppPreferences preferences,
  })  : _locationRepository = locationRepository,
        _preferences = preferences,
        super(const LocationState()) {
    on<LocationPermissionRequested>(_onPermissionRequested);
    on<LocationSkipped>(_onSkipped);
    on<LocationSettingsOpened>(_onSettingsOpened);
  }

  final LocationRepository _locationRepository;
  final AppPreferences _preferences;

  Future<void> _onPermissionRequested(
    LocationPermissionRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(state.copyWith(status: LocationStatus.requesting, clearFailure: true));
    final result = await _locationRepository.requestPermission();
    await result.when(
      ok: (access) async {
        // Mark the prompt as seen on any definite answer so the funnel
        // gate opens; a permanent denial still keeps the user on-screen
        // (see LocationState.isResolved) to offer the settings route.
        await _preferences.setHasSeenLocationPrompt(value: true);
        emit(state.copyWith(status: LocationStatus.resolved, access: access));
      },
      err: (failure) async {
        emit(state.copyWith(status: LocationStatus.initial, failure: failure));
      },
    );
  }

  Future<void> _onSkipped(
    LocationSkipped event,
    Emitter<LocationState> emit,
  ) async {
    await _preferences.setHasSeenLocationPrompt(value: true);
    emit(state.copyWith(
      status: LocationStatus.resolved,
      access: LocationAccess.denied,
    ));
  }

  Future<void> _onSettingsOpened(
    LocationSettingsOpened event,
    Emitter<LocationState> emit,
  ) async {
    await _locationRepository.openSettings();
  }
}

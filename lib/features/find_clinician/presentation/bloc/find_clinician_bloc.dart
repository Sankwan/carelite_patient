import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/clinician_repository.dart';
import '../../domain/search_filter.dart';
import 'find_clinician_event.dart';
import 'find_clinician_state.dart';

class FindClinicianBloc extends Bloc<FindClinicianEvent, FindClinicianState> {
  FindClinicianBloc({required ClinicianRepository clinicianRepository})
      : _clinicianRepository = clinicianRepository,
        super(const FindClinicianState()) {
    on<FindClinicianStarted>((_, emit) => _search(emit));
    on<FindClinicianRetried>((_, emit) => _search(emit));
    on<FindClinicianSpecialtyChanged>(_onSpecialtyChanged);
    on<FindClinicianAvailabilityToggled>(_onAvailabilityToggled);
    on<FindClinicianFiltersCleared>(_onFiltersCleared);
  }

  final ClinicianRepository _clinicianRepository;

  /// Every filter change starts a new request, and a slow earlier one can
  /// land after a faster later one. Without this the list would show results
  /// for a filter the patient has already changed — a bug that looks like
  /// "the filters don't work" and is invisible on a fast connection.
  int _requestToken = 0;

  Future<void> _onSpecialtyChanged(
    FindClinicianSpecialtyChanged event,
    Emitter<FindClinicianState> emit,
  ) async {
    if (event.specialty == state.filter.specialty) return;
    emit(state.copyWith(filter: state.filter.copyWith(specialty: event.specialty)));
    await _search(emit);
  }

  Future<void> _onAvailabilityToggled(
    FindClinicianAvailabilityToggled event,
    Emitter<FindClinicianState> emit,
  ) async {
    emit(state.copyWith(
      filter: state.filter.copyWith(onlineOnly: !state.filter.onlineOnly),
    ));
    await _search(emit);
  }

  Future<void> _onFiltersCleared(
    FindClinicianFiltersCleared event,
    Emitter<FindClinicianState> emit,
  ) async {
    if (!state.filter.isActive) return;
    emit(state.copyWith(filter: const ClinicianFilter()));
    await _search(emit);
  }

  Future<void> _search(Emitter<FindClinicianState> emit) async {
    final token = ++_requestToken;
    final filter = state.filter;

    // Keep the previous results on screen while re-filtering: blanking the
    // list to a spinner on every keystroke makes the screen flash.
    emit(state.copyWith(
      status: state.clinicians.isEmpty
          ? FindClinicianStatus.loading
          : state.status,
      clearFailure: true,
    ));

    try {
      final result = await _clinicianRepository.search(filter);
      if (token != _requestToken) return; // superseded by a newer filter
      result.when(
        ok: (clinicians) => emit(state.copyWith(
          status: FindClinicianStatus.ready,
          clinicians: clinicians,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          // ready, not a failure status: the error is shown over whatever
          // list the patient already had, never instead of it.
          status: FindClinicianStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      if (token != _requestToken) return;
      // The same guard HomeBloc carries: an uncaught throw here would strand
      // the screen on its spinner with nothing explaining why.
      emit(state.copyWith(
        status: FindClinicianStatus.ready,
        failure: UnexpectedFailure(
          'Could not load clinicians (${e.runtimeType}).',
        ),
      ));
    }
  }
}

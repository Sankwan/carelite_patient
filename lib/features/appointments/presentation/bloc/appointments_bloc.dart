import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../home/data/appointment_repository.dart';
import 'appointments_event.dart';
import 'appointments_state.dart';

class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  AppointmentsBloc({
    required AppointmentRepository appointmentRepository,
    Stream<void>? appointmentsChanged,
  })  : _appointmentRepository = appointmentRepository,
        super(const AppointmentsState()) {
    on<AppointmentsStarted>(_onStarted);
    on<AppointmentsRefreshed>(_onRefreshed);
    on<AppointmentsFilterChanged>(_onFilterChanged);
    on<AppointmentCancelled>(_onCancelled);
    _changes = appointmentsChanged?.listen(
      (_) => add(const AppointmentsRefreshed()),
    );
  }

  final AppointmentRepository _appointmentRepository;
  StreamSubscription<void>? _changes;

  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    AppointmentsStarted event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(state.copyWith(status: AppointmentsStatus.loading, clearFailure: true));
    await _load(emit);
  }

  Future<void> _onRefreshed(
    AppointmentsRefreshed event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(state.copyWith(clearFailure: true));
    await _load(emit);
  }

  void _onFilterChanged(
    AppointmentsFilterChanged event,
    Emitter<AppointmentsState> emit,
  ) {
    // Filtering is local: the endpoint has no ?status= filter, so the list
    // already holds both tabs' contents.
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _load(Emitter<AppointmentsState> emit) async {
    try {
      final result = await _appointmentRepository.fetchAll();
      result.when(
        ok: (appointments) => emit(state.copyWith(
          status: AppointmentsStatus.ready,
          appointments: appointments,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          // ready, not a failure status: an error over the list the patient
          // already had beats replacing it with an error page.
          status: AppointmentsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      // The same guard HomeBloc carries — no screen may hang on a spinner.
      emit(state.copyWith(
        status: AppointmentsStatus.ready,
        failure: UnexpectedFailure(
          'Could not load your appointments (${e.runtimeType}).',
        ),
      ));
    }
  }

  /// Deliberately NOT optimistic, unlike marking a notification read.
  ///
  /// Cancelling is destructive and the server can legitimately refuse it (a
  /// completed appointment, one already cancelled elsewhere). Showing it as
  /// gone and then putting it back would be worse than a brief spinner — the
  /// patient would believe they had cancelled when they had not.
  Future<void> _onCancelled(
    AppointmentCancelled event,
    Emitter<AppointmentsState> emit,
  ) async {
    if (state.cancellingId != null) return;

    emit(state.copyWith(cancellingId: event.id, clearFailure: true));

    try {
      final result = await _appointmentRepository.cancel(event.id);
      result.when(
        ok: (cancelled) => emit(state.copyWith(
          appointments: state.appointments
              .map((a) => a.id == cancelled.id ? cancelled : a)
              .toList(growable: false),
          clearCancelling: true,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          clearCancelling: true,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        clearCancelling: true,
        failure: UnexpectedFailure(
          'Could not cancel that appointment (${e.runtimeType}).',
        ),
      ));
    }
  }
}

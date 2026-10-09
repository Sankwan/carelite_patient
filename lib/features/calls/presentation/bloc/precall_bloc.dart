import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/call_repository.dart';
import 'precall_event.dart';
import 'precall_state.dart';

class PrecallBloc extends Bloc<PrecallEvent, PrecallState> {
  PrecallBloc({
    required CallRepository callRepository,
    required this.appointmentId,
  })  : _callRepository = callRepository,
        super(const PrecallState()) {
    on<PrecallStarted>(_onStarted);
    on<PrecallItemToggled>(_onItemToggled);
    on<PrecallSubmitted>(_onSubmitted);
  }

  final CallRepository _callRepository;
  final String appointmentId;

  Future<void> _onStarted(PrecallStarted event, Emitter<PrecallState> emit) async {
    emit(state.copyWith(status: PrecallStepStatus.loading, clearFailure: true));
    try {
      final result = await _callRepository.fetchPrecallStatus(appointmentId);
      result.when(
        ok: (status) => emit(state.copyWith(
          status: PrecallStepStatus.ready,
          serverStatus: status,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: PrecallStepStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      // Same guard every Bloc in this app carries — no screen may hang on
      // a spinner.
      emit(state.copyWith(
        status: PrecallStepStatus.ready,
        failure: UnexpectedFailure(
          'Could not load the checklist (${e.runtimeType}).',
        ),
      ));
    }
  }

  void _onItemToggled(PrecallItemToggled event, Emitter<PrecallState> emit) {
    final current = state.checklist;
    final updated = switch (event.item) {
      PrecallItem.quietLocation =>
        current.copyWith(quietLocation: !current.quietLocation),
      PrecallItem.cameraMicOk =>
        current.copyWith(cameraMicOk: !current.cameraMicOk),
      PrecallItem.connectionOk =>
        current.copyWith(connectionOk: !current.connectionOk),
      PrecallItem.documentsReady =>
        current.copyWith(documentsReady: !current.documentsReady),
    };
    emit(state.copyWith(checklist: updated, clearFailure: true));
  }

  Future<void> _onSubmitted(
    PrecallSubmitted event,
    Emitter<PrecallState> emit,
  ) async {
    // Mirrors the server's own all-or-nothing rule rather than trusting the
    // button's disabled state alone — a defensive re-check, not a race.
    if (!state.checklist.isComplete || state.status == PrecallStepStatus.submitting) {
      return;
    }
    emit(state.copyWith(status: PrecallStepStatus.submitting, clearFailure: true));
    try {
      final result = await _callRepository.submitPrecallChecklist(
        appointmentId,
        state.checklist,
      );
      result.when(
        ok: (status) => emit(state.copyWith(
          status: PrecallStepStatus.ready,
          serverStatus: status,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: PrecallStepStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: PrecallStepStatus.ready,
        failure: UnexpectedFailure(
          'Could not save the checklist (${e.runtimeType}).',
        ),
      ));
    }
  }
}

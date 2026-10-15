import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../home/data/appointment_repository.dart';
import '../../data/call_repository.dart';
import 'incoming_call_event.dart';
import 'incoming_call_state.dart';

/// A clinician is ringing the patient. Answering itself happens on the
/// call screen; this Bloc only decides what Answer leads to, handles
/// Decline, and notices when the call stops ringing.
class IncomingCallBloc extends Bloc<IncomingCallEvent, IncomingCallState> {
  IncomingCallBloc({
    required CallRepository callRepository,
    required AppointmentRepository appointmentRepository,
    required this.callId,
    Stream<String?>? callChanged,
  })  : _calls = callRepository,
        _appointments = appointmentRepository,
        super(const IncomingCallState()) {
    on<IncomingCallStarted>(_onStarted);
    on<IncomingCallDeclined>(_onDeclined);
    on<IncomingCallChanged>(_onChanged);
    _pushes = callChanged
        ?.where((id) => id == null || id == callId)
        .listen((_) => add(const IncomingCallChanged()));
  }

  final CallRepository _calls;
  final AppointmentRepository _appointments;
  final String callId;
  StreamSubscription<String?>? _pushes;

  static const Failure _unreadable =
      UnexpectedFailure('We could not load this call.');

  Future<void> _onStarted(
    IncomingCallStarted event,
    Emitter<IncomingCallState> emit,
  ) async {
    final call = await _calls.fetchCall(callId);
    final session = call.when(ok: (s) => s, err: (_) => null);
    if (session == null) {
      emit(state.copyWith(
        status: IncomingCallStatus.failed,
        failure: call.when(ok: (_) => _unreadable, err: (f) => f),
      ));
      return;
    }
    if (!session.isRinging) {
      emit(state.copyWith(status: IncomingCallStatus.over, session: session));
      return;
    }

    // The appointment gives the caller's real name and specialty; the
    // notification only carries their username.
    // Both requests are in flight at once; awaited one after the other.
    final appointmentsRequest = _appointments.fetchAll();
    final precallRequest = _calls.fetchPrecallStatus(session.appointmentId);
    final appointment = (await appointmentsRequest).when(
      ok: (all) => all.where((a) => a.id == session.appointmentId).firstOrNull,
      err: (_) => null,
    );
    // Unknown counts as not done: the checklist is harmless to repeat.
    final acknowledged = (await precallRequest)
        .when(ok: (s) => s.youAcknowledged, err: (_) => false);
    if (appointment == null) {
      emit(state.copyWith(status: IncomingCallStatus.failed, failure: _unreadable));
      return;
    }

    emit(state.copyWith(
      status: IncomingCallStatus.ringing,
      session: session,
      appointment: appointment,
      needsPrecall: !acknowledged,
      clearFailure: true,
    ));
  }

  Future<void> _onDeclined(
    IncomingCallDeclined event,
    Emitter<IncomingCallState> emit,
  ) async {
    emit(state.copyWith(status: IncomingCallStatus.declining, clearFailure: true));
    final result = await _calls.declineCall(callId);
    result.when(
      ok: (session) =>
          emit(state.copyWith(status: IncomingCallStatus.over, session: session)),
      // Most often "no longer ringing": the clinician hung up first. Either
      // way there is nothing left to answer.
      err: (failure) =>
          emit(state.copyWith(status: IncomingCallStatus.over, failure: failure)),
    );
  }

  Future<void> _onChanged(
    IncomingCallChanged event,
    Emitter<IncomingCallState> emit,
  ) async {
    if (state.status != IncomingCallStatus.ringing) return;
    final result = await _calls.fetchCall(callId);
    result.when(
      ok: (session) {
        if (!session.isRinging) {
          emit(state.copyWith(status: IncomingCallStatus.over, session: session));
        }
      },
      err: (_) {},
    );
  }

  @override
  Future<void> close() {
    _pushes?.cancel();
    return super.close();
  }
}

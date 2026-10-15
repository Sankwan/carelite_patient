import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/call_repository.dart';
import 'call_event.dart';
import 'call_state.dart';

/// Drives one call attempt: initiate, poll while it's live, end.
///
/// [callChanged] carries call ids from the realtime socket (null: any call
/// may have changed): a change to this call is fetched at once, so an answer shows without waiting for the
/// next tick. The `Timer.periodic` poll stays as the fallback for when the
/// socket is down. [pollInterval] is injectable so tests don't wait on the
/// real clock.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({
    required CallRepository callRepository,
    required this.appointmentId,
    this.pollInterval = const Duration(seconds: 3),
    Stream<String?>? callChanged,
  })  : _callRepository = callRepository,
        super(const CallState()) {
    on<CallStarted>(_onStarted);
    on<CallPolled>(_onPolled);
    on<CallEndRequested>(_onEndRequested);
    _pushes = callChanged
        ?.where((id) => id == null || id == state.session?.id)
        .listen((_) => add(const CallPolled()));
  }

  StreamSubscription<String?>? _pushes;

  final CallRepository _callRepository;
  final String appointmentId;
  final Duration pollInterval;

  Timer? _timer;

  Future<void> _onStarted(CallStarted event, Emitter<CallState> emit) async {
    emit(state.copyWith(lifecycle: CallLifecycle.connecting, clearFailure: true));
    try {
      final result =
          await _callRepository.initiateCall(appointmentId, event.mode);
      result.when(
        ok: (session) {
          emit(state.copyWith(
            lifecycle: session.isActive
                ? CallLifecycle.live
                : CallLifecycle.ending,
            session: session,
            clearFailure: true,
          ));
          if (session.isActive) _startPolling();
        },
        err: (failure) => emit(state.copyWith(
          lifecycle: CallLifecycle.failed,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        lifecycle: CallLifecycle.failed,
        failure: UnexpectedFailure('Could not start the call (${e.runtimeType}).'),
      ));
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => add(const CallPolled()));
  }

  Future<void> _onPolled(CallPolled event, Emitter<CallState> emit) async {
    final session = state.session;
    if (session == null || !session.isActive) {
      _timer?.cancel();
      return;
    }
    // A poll tick failing (a dropped connection mid-call) must not blank
    // the screen the patient is actively on — keep showing the last known
    // state and simply try again on the next tick.
    final result = await _callRepository.fetchCall(session.id);
    result.when(
      ok: (updated) {
        emit(state.copyWith(session: updated, clearFailure: true));
        if (!updated.isActive) _timer?.cancel();
      },
      err: (_) {},
    );
  }

  Future<void> _onEndRequested(
    CallEndRequested event,
    Emitter<CallState> emit,
  ) async {
    final session = state.session;
    if (session == null) return;
    _timer?.cancel();
    emit(state.copyWith(lifecycle: CallLifecycle.ending, clearFailure: true));
    try {
      final result = await _callRepository.endCall(session.id);
      result.when(
        ok: (ended) => emit(state.copyWith(
          lifecycle: CallLifecycle.ending,
          session: ended,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          // The call may well have ended anyway (e.g. the other side ended
          // it first, which the server reports as "already ended") — that
          // is not a reason to strand the patient on a live-looking screen.
          lifecycle: CallLifecycle.ending,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        lifecycle: CallLifecycle.ending,
        failure: UnexpectedFailure('Could not end the call (${e.runtimeType}).'),
      ));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _pushes?.cancel();
    return super.close();
  }
}

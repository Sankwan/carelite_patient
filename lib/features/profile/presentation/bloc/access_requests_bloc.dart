import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../../../core/utils/result.dart';
import '../../data/access_repository.dart';
import '../../domain/access_request.dart';
import 'access_requests_event.dart';
import 'access_requests_state.dart';

class AccessRequestsBloc extends Bloc<AccessRequestsEvent, AccessRequestsState> {
  AccessRequestsBloc({required AccessRepository accessRepository})
      : _accessRepository = accessRepository,
        super(const AccessRequestsState()) {
    on<AccessRequestsStarted>((_, emit) => _load(emit));
    on<AccessRequestsRefreshed>((_, emit) => _load(emit));
    on<AccessRequestDecided>(_onDecided);
  }

  final AccessRepository _accessRepository;

  Future<void> _load(Emitter<AccessRequestsState> emit) async {
    try {
      final result = await _accessRepository.fetchRequests();
      result.when(
        ok: (requests) => emit(state.copyWith(
          status: AccessRequestsStatus.ready,
          requests: requests,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: AccessRequestsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: AccessRequestsStatus.ready,
        failure: UnexpectedFailure(
          'Could not load your access requests (${e.runtimeType}).',
        ),
      ));
    }
  }

  Future<void> _onDecided(
    AccessRequestDecided event,
    Emitter<AccessRequestsState> emit,
  ) async {
    emit(state.copyWith(decidingId: event.requestId, clearFailure: true));
    final Future<Result<AccessRequest>> action = switch (event.decision) {
      AccessDecision.approve => _accessRepository.approve(event.requestId),
      AccessDecision.decline => _accessRepository.decline(event.requestId),
      AccessDecision.revoke => _accessRepository.revoke(event.requestId),
    };
    final result = await action;
    result.when(
      ok: (updated) => emit(state.copyWith(
        requests: [
          for (final request in state.requests)
            if (request.id == updated.id) updated else request,
        ],
        clearDecidingId: true,
      )),
      err: (failure) =>
          emit(state.copyWith(failure: failure, clearDecidingId: true)),
    );
  }
}

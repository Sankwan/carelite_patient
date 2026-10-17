import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/vitals_repository.dart';
import 'vitals_event.dart';
import 'vitals_state.dart';

class VitalsBloc extends Bloc<VitalsEvent, VitalsState> {
  VitalsBloc({required VitalsRepository vitalsRepository})
      : _vitalsRepository = vitalsRepository,
        super(const VitalsState()) {
    on<VitalsStarted>((_, emit) => _load(emit));
    on<VitalsRefreshed>((_, emit) => _load(emit));
  }

  final VitalsRepository _vitalsRepository;

  Future<void> _load(Emitter<VitalsState> emit) async {
    try {
      final result = await _vitalsRepository.fetchTrend();
      result.when(
        ok: (records) => emit(state.copyWith(
          status: VitalsStatus.ready,
          records: records,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: VitalsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: VitalsStatus.ready,
        failure:
            UnexpectedFailure('Could not load your vitals (${e.runtimeType}).'),
      ));
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/records_repository.dart';
import '../../domain/consultation.dart';
import 'records_event.dart';
import 'records_state.dart';

/// The records list.
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  RecordsBloc({required RecordsRepository recordsRepository})
      : _recordsRepository = recordsRepository,
        super(const RecordsState()) {
    on<RecordsStarted>(_onStarted);
    on<RecordsRefreshed>(_onRefreshed);
  }

  final RecordsRepository _recordsRepository;

  Future<void> _onStarted(
      RecordsStarted event, Emitter<RecordsState> emit) async {
    emit(state.copyWith(status: RecordsStatus.loading, clearFailure: true));
    await _load(emit);
  }

  Future<void> _onRefreshed(
    RecordsRefreshed event,
    Emitter<RecordsState> emit,
  ) async {
    emit(state.copyWith(clearFailure: true));
    await _load(emit);
  }

  Future<void> _load(Emitter<RecordsState> emit) async {
    try {
      final result = await _recordsRepository.fetchConsultations();
      result.when(
        ok: (consultations) => emit(state.copyWith(
          status: RecordsStatus.ready,
          consultations: consultations,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: RecordsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      // The same guard HomeBloc carries — no screen may hang on a spinner.
      emit(state.copyWith(
        status: RecordsStatus.ready,
        failure: UnexpectedFailure(
          'Could not load your records (${e.runtimeType}).',
        ),
      ));
    }
  }
}

/// One opened record. Separate from [RecordsBloc] because its lifetime is the
/// detail screen's, and because a failure to load one record must not blank
/// the list behind it.
class RecordDetailBloc extends Bloc<RecordsEvent, RecordDetailState> {
  RecordDetailBloc({
    required RecordsRepository recordsRepository,
    required Consultation consultation,
  })  : _recordsRepository = recordsRepository,
        super(RecordDetailState(consultation: consultation)) {
    on<RecordOpened>(_onOpened);
    on<RecordsRefreshed>(
      (event, emit) => _load(state.consultation, emit),
    );
  }

  final RecordsRepository _recordsRepository;

  Future<void> _onOpened(
    RecordOpened event,
    Emitter<RecordDetailState> emit,
  ) async {
    emit(state.copyWith(
      status: RecordDetailStatus.loading,
      clearFailure: true,
    ));
    await _load(event.consultation, emit);
  }

  Future<void> _load(
    Consultation consultation,
    Emitter<RecordDetailState> emit,
  ) async {
    try {
      final result = await _recordsRepository.fetchRecord(consultation);
      result.when(
        ok: (record) => emit(state.copyWith(
          status: RecordDetailStatus.ready,
          record: record,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          status: RecordDetailStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: RecordDetailStatus.ready,
        failure: UnexpectedFailure(
          'Could not open this record (${e.runtimeType}).',
        ),
      ));
    }
  }
}

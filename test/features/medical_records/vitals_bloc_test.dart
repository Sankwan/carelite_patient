import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/medical_records/data/vitals_repository.dart';
import 'package:carelite_app/features/medical_records/domain/vitals_record.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/vitals_bloc.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/vitals_event.dart';
import 'package:carelite_app/features/medical_records/presentation/bloc/vitals_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVitalsRepository extends Mock implements VitalsRepository {}

void main() {
  late _MockVitalsRepository repository;

  final earlier = VitalsRecord(id: '1', recordedAt: DateTime(2026, 9));
  final later = VitalsRecord(id: '2', recordedAt: DateTime(2026, 10));

  setUp(() => repository = _MockVitalsRepository());

  blocTest<VitalsBloc, VitalsState>(
    'loads the trend and exposes it newest-first for display',
    build: () {
      when(() => repository.fetchTrend())
          .thenAnswer((_) async => Result.ok([earlier, later]));
      return VitalsBloc(vitalsRepository: repository);
    },
    act: (bloc) => bloc.add(const VitalsStarted()),
    verify: (bloc) {
      expect(bloc.state.status, VitalsStatus.ready);
      expect(bloc.state.newestFirst, [later, earlier]);
    },
  );

  blocTest<VitalsBloc, VitalsState>(
    'a failed load is shown, not a blank spinner forever',
    build: () {
      when(() => repository.fetchTrend())
          .thenAnswer((_) async => const Result.err(NetworkFailure()));
      return VitalsBloc(vitalsRepository: repository);
    },
    act: (bloc) => bloc.add(const VitalsStarted()),
    verify: (bloc) {
      expect(bloc.state.status, VitalsStatus.ready);
      expect(bloc.state.failure, isA<NetworkFailure>());
    },
  );
}

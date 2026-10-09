import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/calls/data/call_repository.dart';
import 'package:carelite_app/features/calls/domain/precall_checklist.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallRepository extends Mock implements CallRepository {}

void main() {
  late _MockCallRepository repository;

  setUp(() {
    repository = _MockCallRepository();
    registerFallbackValue(const PrecallChecklist());
    when(() => repository.fetchPrecallStatus(any()))
        .thenAnswer((_) async => const Result.ok(PrecallStatus()));
  });

  PrecallBloc buildBloc() =>
      PrecallBloc(callRepository: repository, appointmentId: '15');

  group('PrecallBloc', () {
    blocTest<PrecallBloc, PrecallState>(
      'loads the current gate state on start',
      build: () {
        when(() => repository.fetchPrecallStatus('15')).thenAnswer(
          (_) async =>
              const Result.ok(PrecallStatus(youAcknowledged: true, canJoin: true)),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PrecallStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, PrecallStepStatus.ready);
        expect(bloc.state.serverStatus.youAcknowledged, isTrue);
      },
    );

    blocTest<PrecallBloc, PrecallState>(
      'toggling all four items enables submit, matching the server\'s own '
      'all-or-nothing rule',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const PrecallItemToggled(PrecallItem.quietLocation))
        ..add(const PrecallItemToggled(PrecallItem.cameraMicOk))
        ..add(const PrecallItemToggled(PrecallItem.connectionOk)),
      verify: (bloc) {
        // Three of four ticked — must still be blocked.
        expect(bloc.state.canSubmit, isFalse);
      },
    );

    blocTest<PrecallBloc, PrecallState>(
      'all four ticked enables submit',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const PrecallItemToggled(PrecallItem.quietLocation))
        ..add(const PrecallItemToggled(PrecallItem.cameraMicOk))
        ..add(const PrecallItemToggled(PrecallItem.connectionOk))
        ..add(const PrecallItemToggled(PrecallItem.documentsReady)),
      verify: (bloc) => expect(bloc.state.canSubmit, isTrue),
    );

    blocTest<PrecallBloc, PrecallState>(
      'toggling twice returns an item to unchecked',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const PrecallItemToggled(PrecallItem.quietLocation))
        ..add(const PrecallItemToggled(PrecallItem.quietLocation)),
      verify: (bloc) => expect(bloc.state.checklist.quietLocation, isFalse),
    );

    blocTest<PrecallBloc, PrecallState>(
      'submitting sends the completed checklist and updates the server state',
      build: () {
        when(() => repository.submitPrecallChecklist('15', any())).thenAnswer(
          (_) async => const Result.ok(
            PrecallStatus(youAcknowledged: true, canJoin: true),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc
          ..add(const PrecallItemToggled(PrecallItem.quietLocation))
          ..add(const PrecallItemToggled(PrecallItem.cameraMicOk))
          ..add(const PrecallItemToggled(PrecallItem.connectionOk))
          ..add(const PrecallItemToggled(PrecallItem.documentsReady));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PrecallSubmitted());
      },
      verify: (bloc) {
        expect(bloc.state.serverStatus.youAcknowledged, isTrue);
        expect(bloc.state.status, PrecallStepStatus.ready);
        final sent = verify(() => repository.submitPrecallChecklist(
              '15',
              captureAny(),
            )).captured.single as PrecallChecklist;
        expect(sent.isComplete, isTrue);
      },
    );

    blocTest<PrecallBloc, PrecallState>(
      'submitting an incomplete checklist is a no-op, never a request the '
      'server would reject',
      build: buildBloc,
      act: (bloc) => bloc.add(const PrecallSubmitted()),
      verify: (_) => verifyNever(() => repository.submitPrecallChecklist(any(), any())),
    );

    blocTest<PrecallBloc, PrecallState>(
      'a rejected submission surfaces the failure without discarding the '
      'ticked items',
      build: () {
        when(() => repository.submitPrecallChecklist('15', any())).thenAnswer(
          (_) async => const Result.err(
            ValidationFailure('All checklist items must be confirmed.'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc
          ..add(const PrecallItemToggled(PrecallItem.quietLocation))
          ..add(const PrecallItemToggled(PrecallItem.cameraMicOk))
          ..add(const PrecallItemToggled(PrecallItem.connectionOk))
          ..add(const PrecallItemToggled(PrecallItem.documentsReady));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PrecallSubmitted());
      },
      verify: (bloc) {
        expect(bloc.state.failure, isA<ValidationFailure>());
        expect(bloc.state.checklist.isComplete, isTrue);
      },
    );

    blocTest<PrecallBloc, PrecallState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        when(() => repository.fetchPrecallStatus('15')).thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PrecallStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, PrecallStepStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );
  });
}

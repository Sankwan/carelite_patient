import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/calls/data/call_repository.dart';
import 'package:carelite_app/features/calls/domain/call_session.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallRepository extends Mock implements CallRepository {}

void main() {
  late _MockCallRepository repository;

  CallSession session({
    String id = '5',
    CallStatus status = CallStatus.ringing,
    DateTime? acceptedAt,
    DateTime? endedAt,
  }) {
    return CallSession(
      id: id,
      appointmentId: '15',
      status: status,
      initiatedByUsername: 'kofi',
      roomName: 'room-1',
      joinToken: 'stub-token-room-1',
      createdAt: DateTime.now(),
      acceptedAt: acceptedAt,
      endedAt: endedAt,
    );
  }

  setUp(() {
    repository = _MockCallRepository();
    registerFallbackValue(CallMode.video);
    when(() => repository.initiateCall(any(), any()))
        .thenAnswer((_) async => Result.ok(session()));
  });

  CallBloc buildBloc() => CallBloc(
        callRepository: repository,
        appointmentId: '15',
        // A short interval so polling tests don't wait on the real clock.
        pollInterval: const Duration(milliseconds: 20),
      );

  group('CallBloc', () {
    blocTest<CallBloc, CallState>(
      'initiating a call goes live with the returned session',
      build: buildBloc,
      act: (bloc) => bloc.add(const CallStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.lifecycle, CallLifecycle.live);
        expect(bloc.state.session?.status, CallStatus.ringing);
      },
    );

    blocTest<CallBloc, CallState>(
      'a rejected initiation (no pre-call ack) reaches failed with the '
      'server\'s own reason',
      build: () {
        when(() => repository.initiateCall(any(), any())).thenAnswer(
          (_) async => const Result.err(
            ValidationFailure('Complete the pre-call checklist before starting the call.'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const CallStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.lifecycle, CallLifecycle.failed);
        expect(bloc.state.failure!.message, contains('pre-call checklist'));
      },
    );

    blocTest<CallBloc, CallState>(
      'polls while ringing and reflects the other participant accepting',
      build: () {
        when(() => repository.fetchCall('5')).thenAnswer(
          (_) async => Result.ok(session(
            status: CallStatus.accepted,
            acceptedAt: DateTime.now(),
          )),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CallStarted());
        // Long enough for at least one poll tick to land.
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        expect(bloc.state.session?.status, CallStatus.accepted);
        verify(() => repository.fetchCall('5')).called(greaterThan(0));
      },
    );

    test(
        'polling stops once the call has ended — no request keeps firing '
        'after the fact', () async {
      var pollCount = 0;
      when(() => repository.fetchCall('5')).thenAnswer((_) async {
        pollCount++;
        return Result.ok(session(status: CallStatus.ended));
      });
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const CallStarted());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countAfterEnd = pollCount;
      expect(countAfterEnd, greaterThan(0));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      // The first poll already reported ENDED — no further ticks should
      // fire after that.
      expect(pollCount, countAfterEnd);
    });

    blocTest<CallBloc, CallState>(
      'a poll failure keeps the last known state instead of blanking the '
      'screen mid-call',
      build: () {
        when(() => repository.fetchCall('5'))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CallStarted());
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      verify: (bloc) {
        expect(bloc.state.session?.status, CallStatus.ringing);
        expect(bloc.state.lifecycle, CallLifecycle.live);
      },
    );

    blocTest<CallBloc, CallState>(
      'ending the call stops polling and moves to the finished state',
      build: () {
        when(() => repository.endCall('5')).thenAnswer(
          (_) async => Result.ok(session(
            status: CallStatus.ended,
            endedAt: DateTime.now(),
          )),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const CallStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CallEndRequested());
      },
      verify: (bloc) {
        expect(bloc.state.session?.isFinished, isTrue);
        expect(bloc.state.lifecycle, CallLifecycle.ending);
      },
    );

    blocTest<CallBloc, CallState>(
      'the elapsed time is null until the call is actually accepted',
      build: buildBloc,
      act: (bloc) => bloc.add(const CallStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.session?.elapsedSince(DateTime.now()), isNull);
      },
    );
  });
}

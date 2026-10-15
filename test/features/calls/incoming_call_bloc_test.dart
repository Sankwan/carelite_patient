import 'dart:async';

import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/calls/data/call_repository.dart';
import 'package:carelite_app/features/calls/domain/call_session.dart';
import 'package:carelite_app/features/calls/domain/precall_checklist.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_state.dart';
import 'package:carelite_app/features/calls/presentation/bloc/incoming_call_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/incoming_call_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/incoming_call_state.dart';
import 'package:carelite_app/features/home/data/appointment_repository.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallRepository extends Mock implements CallRepository {}

class _MockAppointmentRepository extends Mock implements AppointmentRepository {}

void main() {
  late _MockCallRepository calls;
  late _MockAppointmentRepository appointments;

  const clinician = Provider(
    id: '2',
    displayName: 'Dr. Kwame Adjei',
    kind: ProviderKind.clinician,
    specialty: 'General Practice',
  );
  final appointment = Appointment(
    id: '15',
    provider: clinician,
    scheduledFor: DateTime(2026, 10, 16, 9),
    status: AppointmentStatus.confirmed,
  );

  CallSession session(CallStatus status) => CallSession(
        id: '5',
        appointmentId: '15',
        status: status,
        initiatedByUsername: 'dr_adjei',
      );

  setUpAll(() => registerFallbackValue(CallMode.video));

  setUp(() {
    calls = _MockCallRepository();
    appointments = _MockAppointmentRepository();
    when(() => calls.fetchCall('5'))
        .thenAnswer((_) async => Result.ok(session(CallStatus.ringing)));
    when(() => appointments.fetchAll())
        .thenAnswer((_) async => Result.ok([appointment]));
    when(() => calls.fetchPrecallStatus('15'))
        .thenAnswer((_) async => const Result.ok(PrecallStatus()));
  });

  IncomingCallBloc build({Stream<String?>? pushes}) => IncomingCallBloc(
        callRepository: calls,
        appointmentRepository: appointments,
        callId: '5',
        callChanged: pushes,
      );

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('rings with the caller from the appointment, checklist still due',
      () async {
    final bloc = build()..add(const IncomingCallStarted());
    await settle();

    expect(bloc.state.status, IncomingCallStatus.ringing);
    expect(bloc.state.appointment?.provider.displayName, 'Dr. Kwame Adjei');
    expect(bloc.state.needsPrecall, isTrue);
    await bloc.close();
  });

  test('a done checklist lets Answer go straight to the call', () async {
    when(() => calls.fetchPrecallStatus('15')).thenAnswer(
      (_) async => const Result.ok(PrecallStatus(youAcknowledged: true)),
    );
    final bloc = build()..add(const IncomingCallStarted());
    await settle();

    expect(bloc.state.needsPrecall, isFalse);
    await bloc.close();
  });

  test('a call that stopped ringing before the screen loaded is over',
      () async {
    when(() => calls.fetchCall('5'))
        .thenAnswer((_) async => Result.ok(session(CallStatus.ended)));
    final bloc = build()..add(const IncomingCallStarted());
    await settle();

    expect(bloc.state.status, IncomingCallStatus.over);
    verifyNever(() => appointments.fetchAll());
    await bloc.close();
  });

  test('declining tells the server and ends the screen', () async {
    when(() => calls.declineCall('5'))
        .thenAnswer((_) async => Result.ok(session(CallStatus.declined)));
    final bloc = build()..add(const IncomingCallStarted());
    await settle();
    bloc.add(const IncomingCallDeclined());
    await settle();

    expect(bloc.state.status, IncomingCallStatus.over);
    expect(bloc.state.session?.status, CallStatus.declined);
    await bloc.close();
  });

  test('the clinician hanging up closes the ringing screen', () async {
    final pushes = StreamController<String?>();
    final bloc = build(pushes: pushes.stream)..add(const IncomingCallStarted());
    await settle();

    when(() => calls.fetchCall('5'))
        .thenAnswer((_) async => Result.ok(session(CallStatus.ended)));
    pushes.add('5');
    await settle();

    expect(bloc.state.status, IncomingCallStatus.over);
    await bloc.close();
    await pushes.close();
  });

  test('answering accepts the existing call instead of starting one',
      () async {
    when(() => calls.acceptCall('5'))
        .thenAnswer((_) async => Result.ok(session(CallStatus.accepted)));
    final bloc = CallBloc(
      callRepository: calls,
      appointmentId: '15',
      pollInterval: const Duration(minutes: 5),
    )..add(const CallAnswered('5'));
    await settle();

    expect(bloc.state.lifecycle, CallLifecycle.live);
    expect(bloc.state.session?.status, CallStatus.accepted);
    verifyNever(() => calls.initiateCall(any(), any()));
    await bloc.close();
  });

  test('an answer refused by the server is shown, not swallowed', () async {
    when(() => calls.acceptCall('5')).thenAnswer(
      (_) async =>
          const Result.err(UnexpectedFailure('This call is no longer ringing.')),
    );
    final bloc = CallBloc(callRepository: calls, appointmentId: '15')
      ..add(const CallAnswered('5'));
    await settle();

    expect(bloc.state.lifecycle, CallLifecycle.failed);
    expect(bloc.state.failure?.message, 'This call is no longer ringing.');
    await bloc.close();
  });
}

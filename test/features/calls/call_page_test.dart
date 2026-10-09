import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/calls/domain/call_session.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/call_state.dart';
import 'package:carelite_app/features/calls/presentation/pages/call_page.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallBloc extends MockBloc<CallEvent, CallState> implements CallBloc {}

class _MockClinicianRepository extends Mock implements ClinicianRepository {}

/// Registers a clinician search that always offers [others], so the
/// "here are other clinicians" sheet has something to show.
void _offerAlternatives(List<Provider> others) {
  final repository = _MockClinicianRepository();
  registerFallbackValue(const ClinicianFilter());
  when(() => repository.search(any()))
      .thenAnswer((_) async => Result.ok(others));
  GetIt.instance.registerSingleton<ClinicianRepository>(repository);
  addTearDown(GetIt.instance.reset);
}

void main() {
  late _MockCallBloc bloc;

  const clinician = Provider(
    id: '6',
    kind: ProviderKind.clinician,
    displayName: 'Dr. Adjei',
    specialty: 'Cardiology',
  );
  final appointment = Appointment(
    id: '15',
    provider: clinician,
    scheduledFor: DateTime.now().add(const Duration(hours: 1)),
    status: AppointmentStatus.confirmed,
  );

  CallSession session({
    CallStatus status = CallStatus.ringing,
    DateTime? acceptedAt,
    DateTime? endedAt,
  }) {
    return CallSession(
      id: '5',
      appointmentId: '15',
      status: status,
      acceptedAt: acceptedAt,
      endedAt: endedAt,
    );
  }

  setUp(() => bloc = _MockCallBloc());

  Future<void> pumpPage(WidgetTester tester, CallState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CallBloc>.value(
          value: bloc,
          child: CallView(appointment: appointment),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the clinician and a ringing indicator', (tester) async {
    await pumpPage(tester, CallState(
      lifecycle: CallLifecycle.live,
      session: session(),
    ));

    expect(find.text('Dr. Adjei'), findsOneWidget);
    expect(find.text('Ringing…'), findsOneWidget);
  });

  testWidgets('never shows real video or a fake "connecting" spinner over '
      'nothing — states plainly that media is not wired', (tester) async {
    await pumpPage(tester, CallState(
      lifecycle: CallLifecycle.live,
      session: session(status: CallStatus.accepted, acceptedAt: DateTime.now()),
    ));

    expect(find.textContaining('not connected in this build'), findsOneWidget);
  });

  testWidgets('shows Connected once accepted', (tester) async {
    await pumpPage(tester, CallState(
      lifecycle: CallLifecycle.live,
      session: session(status: CallStatus.accepted, acceptedAt: DateTime.now()),
    ));

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('the end-call control ends the call', (tester) async {
    await pumpPage(tester, CallState(
      lifecycle: CallLifecycle.live,
      session: session(),
    ));

    await tester.tap(find.byIcon(Icons.call_end));
    await tester.pump();

    verify(() => bloc.add(const CallEndRequested())).called(1);
  });

  testWidgets('a finished call offers a way back, not the end-call control',
      (tester) async {
    await pumpPage(tester, CallState(
      lifecycle: CallLifecycle.ending,
      session: session(status: CallStatus.ended, endedAt: DateTime.now()),
    ));

    expect(find.text('Back to appointment'), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsNothing);
  });

  testWidgets('a failure to initiate is shown, not a silent hang',
      (tester) async {
    await pumpPage(tester, const CallState(
      lifecycle: CallLifecycle.failed,
      failure: ValidationFailure('Complete the pre-call checklist before starting the call.'),
    ));

    expect(find.textContaining('pre-call checklist'), findsOneWidget);
  });

  group('when the clinician cannot be reached', () {
    const boateng = Provider(
      id: '8',
      kind: ProviderKind.clinician,
      displayName: 'Dr. Boateng',
      specialty: 'Cardiology',
      isAvailable: true,
    );

    testWidgets('a declined call says so and offers another clinician',
        (tester) async {
      _offerAlternatives([clinician, boateng]);
      whenListen(
        bloc,
        Stream.fromIterable([
          CallState(
            lifecycle: CallLifecycle.live,
            session: session(status: CallStatus.declined),
          ),
        ]),
        initialState:
            CallState(lifecycle: CallLifecycle.live, session: session()),
      );
      await pumpPage(tester, bloc.state);
      await tester.pumpAndSettle();

      expect(find.text('Dr. Adjei can\'t take the call right now'),
          findsOneWidget);
      // The clinician who declined is not offered back.
      expect(find.text('Dr. Boateng'), findsOneWidget);
      expect(find.text('Available now'), findsOneWidget);
    });

    testWidgets('an unanswered call offers to keep waiting or see someone '
        'else', (tester) async {
      _offerAlternatives([boateng]);
      when(() => bloc.state).thenReturn(
        CallState(lifecycle: CallLifecycle.live, session: session()),
      );
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<CallBloc>.value(
            value: bloc,
            child: CallView(
              appointment: appointment,
              ringTimeout: const Duration(seconds: 5),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('hasn\'t answered'), findsNothing);

      // Not pumpAndSettle: the ringing spinner never stops animating.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Dr. Adjei hasn\'t answered yet'), findsOneWidget);
      expect(find.text('Keep waiting'), findsOneWidget);
      expect(find.text('Dr. Boateng'), findsOneWidget);

      await tester.tap(find.text('Keep waiting'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Still ringing: nothing was ended on the patient's behalf.
      verifyNever(() => bloc.add(const CallEndRequested()));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a dropped connection offers a retry, not a different doctor',
        (tester) async {
      _offerAlternatives([boateng]);
      await pumpPage(tester, const CallState(
        lifecycle: CallLifecycle.failed,
        failure: NetworkFailure(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your connection dropped'), findsOneWidget);
      expect(find.text('Dr. Boateng'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const CallStarted())).called(1);
    });
  });
}

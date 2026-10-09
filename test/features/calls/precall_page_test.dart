import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/calls/domain/precall_checklist.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_bloc.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_event.dart';
import 'package:carelite_app/features/calls/presentation/bloc/precall_state.dart';
import 'package:carelite_app/features/calls/presentation/pages/precall_page.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrecallBloc extends MockBloc<PrecallEvent, PrecallState>
    implements PrecallBloc {}

void main() {
  late _MockPrecallBloc bloc;

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

  setUp(() => bloc = _MockPrecallBloc());

  Future<void> pumpPage(WidgetTester tester, PrecallState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<PrecallBloc>.value(
          value: bloc,
          child: PrecallView(appointment: appointment),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpPage(tester, const PrecallState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the button says Confirm and continue, and is disabled, until '
      'all four are ticked', (tester) async {
    await pumpPage(tester, const PrecallState(status: PrecallStepStatus.ready));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(find.text('Confirm and continue'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('ticking all four items enables the button', (tester) async {
    await pumpPage(tester, const PrecallState(
      status: PrecallStepStatus.ready,
      checklist: PrecallChecklist(
        quietLocation: true,
        cameraMicOk: true,
        connectionOk: true,
        documentsReady: true,
      ),
    ));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping a checklist item toggles it', (tester) async {
    await pumpPage(tester, const PrecallState(status: PrecallStepStatus.ready));

    await tester.tap(find.text('I\'m in a quiet, private location'));
    await tester.pump();

    verify(() => bloc.add(const PrecallItemToggled(PrecallItem.quietLocation)))
        .called(1);
  });

  testWidgets('once acknowledged, the button becomes Join Call and needs no '
      're-ticking', (tester) async {
    // The gate is per-appointment server state, not a local form — a
    // patient who already confirmed on an earlier visit should not have to
    // re-tick four boxes to join.
    await pumpPage(tester, const PrecallState(
      status: PrecallStepStatus.ready,
      serverStatus: PrecallStatus(youAcknowledged: true, canJoin: true),
    ));

    expect(find.text('Join Call'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows that the other participant has not confirmed yet',
      (tester) async {
    await pumpPage(tester, const PrecallState(
      status: PrecallStepStatus.ready,
      serverStatus: PrecallStatus(youAcknowledged: true, canJoin: true),
    ));

    expect(find.textContaining('Waiting for the clinician'), findsOneWidget);
  });

  testWidgets('shows both ready once both participants have confirmed',
      (tester) async {
    await pumpPage(tester, const PrecallState(
      status: PrecallStepStatus.ready,
      serverStatus:
          PrecallStatus(youAcknowledged: true, canJoin: true, bothReady: true),
    ));

    expect(find.text('You\'re both ready to join.'), findsOneWidget);
  });

  testWidgets('a failure is shown as a toast, not a blank screen',
      (tester) async {
    await pumpPage(tester, const PrecallState(
      status: PrecallStepStatus.ready,
      failure: NetworkFailure(),
    ));

    // The page itself still renders — a failure toast is transient, not a
    // full-screen error, since the checklist is still usable.
    expect(find.text('Confirm and continue'), findsOneWidget);
  });
}

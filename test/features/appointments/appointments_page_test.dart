import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_bloc.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_event.dart';
import 'package:carelite_app/features/appointments/presentation/bloc/appointments_state.dart';
import 'package:carelite_app/features/appointments/presentation/pages/appointments_page.dart';
import 'package:carelite_app/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppointmentsBloc
    extends MockBloc<AppointmentsEvent, AppointmentsState>
    implements AppointmentsBloc {}

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
  late _MockAppointmentsBloc bloc;

  const clinician = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
  );

  Appointment build(String id, AppointmentStatus status,
          {Duration from = const Duration(days: 1)}) =>
      Appointment(
        id: id,
        provider: clinician,
        scheduledFor: DateTime.now().add(from),
        status: status,
      );

  setUp(() => bloc = _MockAppointmentsBloc());

  Future<void> pumpPage(WidgetTester tester, AppointmentsState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AppointmentsBloc>.value(
          value: bloc,
          child: const AppointmentsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpPage(tester, const AppointmentsState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders only the selected tab', (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [
        build('1', AppointmentStatus.confirmed),
        build('2', AppointmentStatus.completed),
      ],
    ));

    expect(find.byType(AppointmentCard), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Upcoming (1)'), findsOneWidget);
  });

  testWidgets('a requested appointment reads as awaiting confirmation, not '
      '"requested"', (tester) async {
    // REQUESTED means no clinician has accepted yet — wording the patient
    // can act on.
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [build('1', AppointmentStatus.requested)],
    ));

    expect(find.text('Awaiting confirmation'), findsOneWidget);
  });

  testWidgets('a REQUESTED appointment offers no Join call', (tester) async {
    // No clinician has accepted yet — joining before that would let the
    // patient try to enter a call no clinician agreed to.
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [build('1', AppointmentStatus.requested)],
    ));
    expect(find.text('Join call'), findsNothing);
  });

  testWidgets('a CONFIRMED appointment offers "I\'m ready" inside its window',
      (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [
        build('2', AppointmentStatus.confirmed,
            from: const Duration(minutes: 5)),
      ],
    ));
    expect(find.text('I\'m ready'), findsOneWidget);
  });

  testWidgets('a CONFIRMED appointment nobody started in time reads as missed',
      (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [
        build('3', AppointmentStatus.confirmed,
            from: const Duration(minutes: -20)),
      ],
    ));
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('I\'m ready'), findsNothing);
  });

  testWidgets('a past appointment offers no Cancel', (tester) async {
    // The server refuses it, so the button is absent rather than rejected.
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      filter: AppointmentsFilter.past,
      appointments: [build('1', AppointmentStatus.completed)],
    ));

    expect(find.byType(AppointmentCard), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('cancelling asks for confirmation first', (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [build('1', AppointmentStatus.confirmed)],
    ));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Cancelling cannot be undone — there is no un-cancel endpoint.
    expect(find.text('Cancel this appointment?'), findsOneWidget);
    verifyNever(() => bloc.add(const AppointmentCancelled('1')));

    await tester.tap(find.text('Cancel appointment'));
    await tester.pumpAndSettle();
    verify(() => bloc.add(const AppointmentCancelled('1'))).called(1);
  });

  testWidgets('backing out of the dialog cancels nothing', (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [build('1', AppointmentStatus.confirmed)],
    ));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(const AppointmentCancelled('1')));
  });

  testWidgets('the row being cancelled shows its own spinner', (tester) async {
    await pumpPage(tester, AppointmentsState(
      status: AppointmentsStatus.ready,
      appointments: [build('1', AppointmentStatus.confirmed)],
      cancellingId: '1',
    ));

    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty list is still pull-to-refreshable', (tester) async {
    await pumpPage(tester, const AppointmentsState(
      status: AppointmentsStatus.ready,
    ));

    expect(find.text('No upcoming appointments'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  group('after a cancel', () {
    const boateng = Provider(
      id: '8',
      kind: ProviderKind.clinician,
      displayName: 'Dr. Boateng',
      specialty: 'Cardiology',
      isAvailable: true,
    );

    testWidgets('a confirmed cancel offers another clinician', (tester) async {
      _offerAlternatives([clinician, boateng]);
      final cancelling = AppointmentsState(
        status: AppointmentsStatus.ready,
        appointments: [build('9', AppointmentStatus.confirmed)],
        cancellingId: '9',
      );
      whenListen(
        bloc,
        Stream.fromIterable([
          AppointmentsState(
            status: AppointmentsStatus.ready,
            appointments: [build('9', AppointmentStatus.cancelled)],
          ),
        ]),
        initialState: cancelling,
      );
      await pumpPage(tester, cancelling);
      await tester.pumpAndSettle();

      expect(find.text('Appointment cancelled'), findsOneWidget);
      expect(find.text('Dr. Boateng'), findsOneWidget);
      expect(find.text('No, thanks'), findsOneWidget);
    });

    testWidgets('a refused cancel offers nobody — nothing was cancelled',
        (tester) async {
      _offerAlternatives([boateng]);
      final cancelling = AppointmentsState(
        status: AppointmentsStatus.ready,
        appointments: [build('9', AppointmentStatus.confirmed)],
        cancellingId: '9',
      );
      whenListen(
        bloc,
        Stream.fromIterable([
          AppointmentsState(
            status: AppointmentsStatus.ready,
            appointments: [build('9', AppointmentStatus.confirmed)],
            failure: const ValidationFailure(
              'This appointment can no longer be cancelled.',
            ),
          ),
        ]),
        initialState: cancelling,
      );
      await pumpPage(tester, cancelling);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Appointment cancelled'), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}

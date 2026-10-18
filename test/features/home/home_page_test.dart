import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/money.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_event.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_state.dart';
import 'package:carelite_app/features/home/presentation/pages/home_page.dart';
import 'package:carelite_app/features/home/presentation/widgets/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

void main() {
  const clinician = Provider(
    id: 'c1',
    kind: ProviderKind.clinician,
    displayName: 'Dr. Kojo Boateng',
    // The Figma Home screen calls him "Cardiologist" in the hero and
    // "General Practitioner" in the list below. One record, one answer.
    specialty: 'Cardiologist',
    rating: 4.8,
    consultationFee: Money(9000),
    distanceMetres: 1140,
  );
  final upcoming = Appointment(
    id: 'a1',
    provider: clinician,
    scheduledFor: DateTime.now().add(const Duration(hours: 3)),
    status: AppointmentStatus.confirmed,
    escrowStatus: 'held',
  );
  final past = Appointment(
    id: 'a0',
    provider: clinician,
    scheduledFor: DateTime.now().subtract(const Duration(days: 9)),
    status: AppointmentStatus.completed,
    notes: 'Reviewed BP log.',
  );

  late _MockHomeBloc bloc;

  setUp(() => bloc = _MockHomeBloc());

  Future<void> pumpHome(WidgetTester tester, HomeState state) async {
    when(() => bloc.state).thenReturn(state);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<HomeBloc>.value(value: bloc, child: const HomePage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('new user sees no appointment or activity sections',
      (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      patientName: 'Esi Owusu',
      nearbyClinicians: [clinician],
      hasLocation: true,
    ));

    // Requirement #6 — the whole point of the new-user state.
    expect(find.text('UPCOMING APPOINTMENT'), findsNothing);
    expect(find.text('Recent Activity'), findsNothing);

    // ...but the dashboard is not empty: clinicians are its main content,
    // so a new patient's first prompt is a doctor to book.
    expect(find.textContaining('Esi'), findsOneWidget);
    expect(find.text('What do you need today?'), findsOneWidget);
    expect(find.text('Top clinicians'), findsOneWidget);
    expect(find.text('Dr. Kojo Boateng'), findsOneWidget);
  });

  testWidgets('never offers a route straight to a lab or pharmacy',
      (tester) async {
    // Diagnostics are clinician-initiated: ordered during a consultation,
    // approved and paid for by the patient, and only then is a nearby lab
    // offered (docs/PRODUCT_PATHWAY.md). Home must not short-circuit
    // that by letting a patient walk into a lab unreferred.
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      patientName: 'Esi Owusu',
      nearbyClinicians: [clinician],
      hasLocation: true,
    ));

    expect(find.text('Nearby Diagnostic Labs & Pharmacies'), findsNothing);
    expect(find.text('Accra Diagnostic Centre'), findsNothing);
  });

  testWidgets('returning user sees the hero card, clinicians and activity',
      (tester) async {
    await pumpHome(tester, HomeState(
      status: HomeStatus.ready,
      patientName: 'Esi Owusu',
      upcoming: upcoming,
      nearbyClinicians: const [clinician],
      recentActivity: [past],
      hasLocation: true,
    ));

    expect(find.text('UPCOMING APPOINTMENT'), findsOneWidget);
    expect(find.text('Top clinicians'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    // Three hours out: nothing to join yet, so it says when it opens.
    expect(find.textContaining('Get ready from'), findsOneWidget);

    // Escrow status is surfaced read-only (requirement #9).
    expect(
      find.textContaining('Payment held securely'),
      findsOneWidget,
    );
  });

  testWidgets('one specialty renders identically in the hero and the list',
      (tester) async {
    await pumpHome(tester, HomeState(
      status: HomeStatus.ready,
      upcoming: upcoming,
      nearbyClinicians: const [clinician],
      hasLocation: true,
    ));

    // Both the hero card and the list row read from the same Provider, so
    // "Cardiologist" appears twice and "General Practitioner" never.
    expect(find.text('Cardiologist'), findsNWidgets(2));
    expect(find.text('General Practitioner'), findsNothing);
  });

  testWidgets('omits distances but still lists providers without location',
      (tester) async {
    const noDistance = Provider(
      id: 'c2',
      kind: ProviderKind.clinician,
      displayName: 'Dr. Efua Mensah',
      specialty: 'Hypertension Specialist',
    );
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [noDistance],
    ));

    expect(find.text('Dr. Efua Mensah'), findsOneWidget);
    expect(find.textContaining(' km'), findsNothing);
    // A bare ' m' substring match is time-of-day flaky: the greeting reads
    // "Good morning" for part of the day, which itself contains ' m'. A
    // distance label is always digits immediately before the unit ("850 m"),
    // so anchor on that instead of the bare substring.
    expect(find.textContaining(RegExp(r'\d+ m\b')), findsNothing);
  });

  testWidgets('a zero unread count leaves no dot on the bell', (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
    ));

    // Zero is also what the Bloc falls back to when the count cannot be
    // fetched, so this is the "we don't know" rendering too — a badge the
    // patient can never clear would be worse than none.
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('an unread notification puts a badge on the bell',
      (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
      unreadNotifications: 2,
    ));

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });

  testWidgets('shows the real place name under the greeting, not a generic '
      'label', (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
      hasLocation: true,
      locationLabel: 'Tamale, Northern Region',
    ));

    expect(find.text('Tamale, Northern Region'), findsOneWidget);
    expect(find.text('Near you'), findsNothing);
  });

  testWidgets('falls back to a generic label when the position is known but '
      'could not be named', (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
      hasLocation: true,
    ));

    expect(find.text('Near you'), findsOneWidget);
  });

  testWidgets(
      'the avatar shows the patient\'s real initials, never "?" for a '
      'signed-in account', (tester) async {
    // The exact bug reported live: AuthUser.fullName is always null on this
    // backend, so every patient's avatar showed a bare question mark.
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
      patientUsername: 'kofi',
    ));

    final avatar = tester.widget<AvatarCircle>(find.byType(AvatarCircle).first);
    expect(avatar.name, 'Kofi');
    expect(find.descendant(
      of: find.byType(AvatarCircle).first,
      matching: find.text('?'),
    ), findsNothing);
  });

  testWidgets('the greeting itself still says nothing invented — no name on '
      'this backend means a plain greeting, only the avatar gets the '
      'fallback', (tester) async {
    await pumpHome(tester, const HomeState(
      status: HomeStatus.ready,
      nearbyClinicians: [clinician],
      patientUsername: 'kofi',
    ));

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.textContaining('Kofi'), findsNothing);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await pumpHome(tester, const HomeState());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

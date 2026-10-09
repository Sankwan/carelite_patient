import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/home/data/appointment_repository.dart';
import 'package:carelite_app/features/home/data/provider_repository.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_event.dart';
import 'package:carelite_app/features/home/presentation/bloc/home_state.dart';
import 'package:carelite_app/features/location/data/location_repository.dart';
import 'package:carelite_app/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAppointmentRepository extends Mock implements AppointmentRepository {}

class _MockProviderRepository extends Mock implements ProviderRepository {}

class _MockLocationRepository extends Mock implements LocationRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late _MockAppointmentRepository appointments;
  late _MockProviderRepository providers;
  late _MockLocationRepository location;
  late _MockNotificationRepository notifications;

  const patientId = 'patient-1';
  const osu = (latitude: 5.5560, longitude: -0.1969);

  const clinician = Provider(
    id: 'c1',
    kind: ProviderKind.clinician,
    displayName: 'Dr. Kojo Boateng',
    specialty: 'Cardiologist',
    rating: 4.8,
    distanceMetres: 1140,
  );
  const lab = Provider(
    id: 'l1',
    kind: ProviderKind.lab,
    displayName: 'Accra Diagnostic Centre',
    distanceMetres: 1467,
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
  );

  setUp(() {
    appointments = _MockAppointmentRepository();
    providers = _MockProviderRepository();
    location = _MockLocationRepository();
    notifications = _MockNotificationRepository();
    registerFallbackValue(osu);

    when(() => notifications.fetchUnreadCount())
        .thenAnswer((_) async => const Result.ok(0));

    when(() => location.currentPosition())
        .thenAnswer((_) async => const Result.ok(osu));
    when(() => location.placeNameFor(any()))
        .thenAnswer((_) async => const Result.ok('Osu, Accra'));
    when(() => providers.fetchNearby(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          kind: any(named: 'kind'),
          radiusMetres: any(named: 'radiusMetres'),
          limit: any(named: 'limit'),
        )).thenAnswer((invocation) async {
      final kind = invocation.namedArguments[#kind] as ProviderKind?;
      if (kind == ProviderKind.clinician) return const Result.ok([clinician]);
      return const Result.ok([clinician, lab]);
    });
    when(() => providers.fetchVerified(
          kind: any(named: 'kind'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Result.ok([clinician]));
  });

  HomeBloc buildBloc() => HomeBloc(
        appointmentRepository: appointments,
        providerRepository: providers,
        locationRepository: location,
        notificationRepository: notifications,
      );

  void stubAppointments({Appointment? next, List<Appointment> recent = const []}) {
    when(() => appointments.fetchUpcoming(patientId))
        .thenAnswer((_) async => Result.ok(next));
    when(() => appointments.fetchRecent(patientId, limit: any(named: 'limit')))
        .thenAnswer((_) async => Result.ok(recent));
  }

  group('HomeBloc', () {
    blocTest<HomeBloc, HomeState>(
      'never fetches labs or pharmacies for the dashboard',
      build: () {
        stubAppointments();
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      verify: (_) {
        // Diagnostics are clinician-initiated (docs/PRODUCT_PATHWAY.md): Home
        // must not offer a route straight to a lab, so it only ever asks
        // for clinicians.
        final kinds = verify(() => providers.fetchNearby(
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              kind: captureAny(named: 'kind'),
              radiusMetres: any(named: 'radiusMetres'),
              limit: any(named: 'limit'),
            )).captured;
        expect(kinds, everyElement(ProviderKind.clinician));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a patient with no history lands in the new-user state',
      build: () {
        stubAppointments();
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1, // the loading state
      verify: (bloc) {
        // Requirement #6: no upcoming card and no Recent Activity for a
        // brand-new patient — but clinicians still load, because that is
        // the main content of a new patient's dashboard.
        expect(bloc.state.isNewUser, isTrue);
        expect(bloc.state.upcoming, isNull);
        expect(bloc.state.recentActivity, isEmpty);
        expect(bloc.state.nearbyClinicians, isNotEmpty);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'a patient with an appointment lands in the returning-user state',
      build: () {
        stubAppointments(next: upcoming, recent: [past]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.isNewUser, isFalse);
        expect(bloc.state.upcoming, upcoming);
        expect(bloc.state.recentActivity, [past]);
        expect(bloc.state.nearbyClinicians, isNotEmpty);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'still loads providers when the patient declined location',
      build: () {
        stubAppointments();
        when(() => location.currentPosition())
            .thenAnswer((_) async => const Result.ok(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        // Refusing location costs the distance labels, nothing else — the
        // dashboard must never be empty because of it.
        expect(bloc.state.hasLocation, isFalse);
        expect(bloc.state.nearbyClinicians, isNotEmpty);
        verify(() => providers.fetchVerified(
              kind: any(named: 'kind'),
              limit: any(named: 'limit'),
            )).called(greaterThan(0));
        verifyNever(() => providers.fetchNearby(
              latitude: any(named: 'latitude'),
              longitude: any(named: 'longitude'),
              kind: any(named: 'kind'),
              radiusMetres: any(named: 'radiusMetres'),
              limit: any(named: 'limit'),
            ));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'shows the real place name on the header once a position is known',
      build: () {
        stubAppointments();
        when(() => location.placeNameFor(any()))
            .thenAnswer((_) async => const Result.ok('Osu, Accra'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) => expect(bloc.state.locationLabel, 'Osu, Accra'),
    );

    blocTest<HomeBloc, HomeState>(
      'no place name is a decoration failure, not a dashboard failure',
      build: () {
        stubAppointments(next: upcoming);
        when(() => location.placeNameFor(any()))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        // The header falls back to a generic label for this, never an error
        // banner over an otherwise-fine dashboard.
        expect(bloc.state.locationLabel, isNull);
        expect(bloc.state.failure, isNull);
        expect(bloc.state.upcoming, upcoming);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'never geocodes when the patient declined location — nothing to name',
      build: () {
        stubAppointments();
        when(() => location.currentPosition())
            .thenAnswer((_) async => const Result.ok(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.locationLabel, isNull);
        verifyNever(() => location.placeNameFor(any()));
      },
    );

    blocTest<HomeBloc, HomeState>(
      'surfaces a failure without blanking the sections that did load',
      build: () {
        when(() => appointments.fetchUpcoming(patientId))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        when(() => appointments.fetchRecent(patientId, limit: any(named: 'limit')))
            .thenAnswer((_) async => const Result.ok([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, HomeStatus.ready);
        expect(bloc.state.failure, isA<NetworkFailure>());
        expect(bloc.state.nearbyClinicians, isNotEmpty);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'reaches HomeStatus.ready with a failure even if a repository throws '
      'outright, instead of hanging on HomeStatus.loading forever',
      build: () {
        // Regression test: this is the exact failure mode that shipped —
        // an uncaught exception inside Future.wait left the Bloc (and the
        // spinner on screen) stuck on HomeStatus.loading with no error ever
        // surfaced. Every current repository has since been made not to
        // throw, so this stubs one throwing anyway to prove the Bloc's own
        // catch is what actually guarantees the screen can never hang again,
        // regardless of what a future repository change gets wrong.
        when(() => appointments.fetchUpcoming(patientId))
            .thenThrow(StateError('boom'));
        when(() => appointments.fetchRecent(patientId, limit: any(named: 'limit')))
            .thenAnswer((_) async => const Result.ok([]));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, HomeStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'carries the unread count through to the header badge',
      build: () {
        stubAppointments();
        when(() => notifications.fetchUnreadCount())
            .thenAnswer((_) async => const Result.ok(3));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) => expect(bloc.state.unreadNotifications, 3),
    );

    blocTest<HomeBloc, HomeState>(
      'an unreachable unread count leaves the badge off rather than '
      'erroring the whole dashboard',
      build: () {
        stubAppointments(next: upcoming);
        when(() => notifications.fetchUnreadCount())
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const HomeStarted(patientId: patientId)),
      skip: 1,
      verify: (bloc) {
        // The badge is decoration on top of the dashboard, not part of it:
        // failing to count unread notifications must not put an error banner
        // in front of a patient whose appointment card loaded perfectly.
        expect(bloc.state.unreadNotifications, 0);
        expect(bloc.state.failure, isNull);
        expect(bloc.state.upcoming, upcoming);
      },
    );

    test('greeting is computed from the clock, not hardcoded', () {
      const state = HomeState();
      expect(state.greeting(now: DateTime(2026, 9, 1, 8)), 'Good morning');
      expect(state.greeting(now: DateTime(2026, 9, 1, 13)), 'Good afternoon');
      expect(state.greeting(now: DateTime(2026, 9, 1, 20)), 'Good evening');
    });

    test('firstName takes only the first word of the full name', () {
      const state = HomeState(patientName: 'Esi Akosua Owusu');
      expect(state.firstName, 'Esi');
      expect(const HomeState().firstName, isNull);
    });

    test('avatarLabel falls back to the formatted username when there is no '
        'real name — this backend never has one', () {
      // The exact bug reported live: every signed-in patient showed '?' on
      // Home because AuthUser.fullName is always null on this backend.
      const state = HomeState(patientUsername: 'kofi');
      expect(state.avatarLabel, 'Kofi');
    });

    test('avatarLabel prefers a real name over the username, if one is ever '
        'set', () {
      const state = HomeState(
        patientName: 'Esi Owusu',
        patientUsername: 'esi_owusu',
      );
      expect(state.avatarLabel, 'Esi');
    });

    test('avatarLabel is null only when there is truly nothing to derive it '
        'from — never an empty string', () {
      expect(const HomeState().avatarLabel, isNull);
      expect(const HomeState(patientUsername: '').avatarLabel, isNull);
      expect(const HomeState(patientUsername: '   ').avatarLabel, isNull);
    });
  });
}

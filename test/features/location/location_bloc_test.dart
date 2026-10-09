import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/storage/app_preferences.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/location/data/location_repository.dart';
import 'package:carelite_app/features/location/presentation/bloc/location_bloc.dart';
import 'package:carelite_app/features/location/presentation/bloc/location_event.dart';
import 'package:carelite_app/features/location/presentation/bloc/location_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  // A real AppPreferences over an in-memory store rather than a mock: the
  // point of most of these tests is that the "already asked" flag actually
  // gets written, which a mock would only pretend to do.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLocationRepository locationRepository;
  late AppPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    locationRepository = _MockLocationRepository();
    preferences = await AppPreferences.resolve();
  });

  LocationBloc buildBloc() => LocationBloc(
        locationRepository: locationRepository,
        preferences: preferences,
      );

  group('LocationBloc', () {
    blocTest<LocationBloc, LocationState>(
      'emits [requesting, resolved+granted] and records the prompt as seen',
      build: () {
        when(() => locationRepository.requestPermission())
            .thenAnswer((_) async => const Result.ok(LocationAccess.granted));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LocationPermissionRequested()),
      expect: () => [
        const LocationState(status: LocationStatus.requesting),
        const LocationState(
          status: LocationStatus.resolved,
          access: LocationAccess.granted,
        ),
      ],
      verify: (_) => expect(preferences.hasSeenLocationPrompt, isTrue),
    );

    blocTest<LocationBloc, LocationState>(
      'treats "Maybe Later" as resolved so the funnel is never a dead end',
      build: buildBloc,
      act: (bloc) => bloc.add(const LocationSkipped()),
      expect: () => [
        const LocationState(
          status: LocationStatus.resolved,
          access: LocationAccess.denied,
        ),
      ],
      verify: (_) => expect(preferences.hasSeenLocationPrompt, isTrue),
    );

    blocTest<LocationBloc, LocationState>(
      'keeps the user on screen when access is permanently denied',
      build: () {
        when(() => locationRepository.requestPermission()).thenAnswer(
          (_) async => const Result.ok(LocationAccess.deniedForever),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LocationPermissionRequested()),
      // isResolved stays false so the page can offer the settings route
      // instead of silently moving on with no way to grant access.
      verify: (bloc) => expect(bloc.state.isResolved, isFalse),
    );

    blocTest<LocationBloc, LocationState>(
      'surfaces a failure and stays on the prompt',
      build: () {
        when(() => locationRepository.requestPermission())
            .thenAnswer((_) async => const Result.err(UnexpectedFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LocationPermissionRequested()),
      expect: () => [
        const LocationState(status: LocationStatus.requesting),
        isA<LocationState>()
            .having((s) => s.status, 'status', LocationStatus.initial)
            .having((s) => s.failure, 'failure', isA<UnexpectedFailure>()),
      ],
      verify: (_) => expect(preferences.hasSeenLocationPrompt, isFalse),
    );

    blocTest<LocationBloc, LocationState>(
      'delegates to the OS settings page',
      build: () {
        when(() => locationRepository.openSettings()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LocationSettingsOpened()),
      verify: (_) => verify(() => locationRepository.openSettings()).called(1),
    );
  });
}

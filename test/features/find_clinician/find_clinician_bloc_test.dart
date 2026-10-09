import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/find_clinician/data/clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_bloc.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_event.dart';
import 'package:carelite_app/features/find_clinician/presentation/bloc/find_clinician_state.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClinicianRepository extends Mock implements ClinicianRepository {}

void main() {
  late _MockClinicianRepository repository;

  const adjei = Provider(
    id: '5',
    kind: ProviderKind.clinician,
    displayName: 'dr_adjei',
    specialty: 'Cardiology',
    rating: 4.8,
    isAvailable: true,
  );
  const mensah = Provider(
    id: '6',
    kind: ProviderKind.clinician,
    displayName: 'dr_mensah',
    specialty: 'Pediatrics',
    rating: 4.7,
  );

  setUp(() {
    repository = _MockClinicianRepository();
    registerFallbackValue(const ClinicianFilter());
    when(() => repository.search(any()))
        .thenAnswer((_) async => const Result.ok([adjei, mensah]));
  });

  FindClinicianBloc buildBloc() =>
      FindClinicianBloc(clinicianRepository: repository);

  group('FindClinicianBloc', () {
    blocTest<FindClinicianBloc, FindClinicianState>(
      'loads the unfiltered list on start',
      build: buildBloc,
      act: (bloc) => bloc.add(const FindClinicianStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, FindClinicianStatus.ready);
        expect(bloc.state.clinicians, [adjei, mensah]);
        expect(bloc.state.filter.isActive, isFalse);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'a specialty change re-queries the server rather than filtering the '
      'page it already has',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        when(() => repository.search(any()))
            .thenAnswer((_) async => const Result.ok([adjei]));
        bloc.add(const FindClinicianSpecialtyChanged('Cardiology'));
      },
      verify: (bloc) {
        // Filtering client-side would be wrong the moment the result set
        // exceeds one page of 20.
        final filters =
            verify(() => repository.search(captureAny())).captured;
        expect(filters.last, const ClinicianFilter(specialty: 'Cardiology'));
        expect(bloc.state.clinicians, [adjei]);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'toggling availability flips the filter and re-queries',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FindClinicianAvailabilityToggled());
      },
      verify: (bloc) {
        expect(bloc.state.filter.onlineOnly, isTrue);
        final filters =
            verify(() => repository.search(captureAny())).captured;
        expect((filters.last as ClinicianFilter).onlineOnly, isTrue);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'an unchanged specialty does not fire another request',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FindClinicianSpecialtyChanged(''));
      },
      // The debounced field re-emits the same value on blur; re-querying for
      // it would be a wasted round trip on every focus change.
      verify: (_) => verify(() => repository.search(any())).called(1),
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'a slow earlier search cannot overwrite a newer one',
      build: () {
        // The exact bug this guards: type "Cardio", then "Dermatology"; the
        // first request is slower and lands last, leaving Cardiology results
        // under a Dermatology filter. Reads as "the filters don't work" and
        // is invisible on a fast connection.
        var call = 0;
        when(() => repository.search(any())).thenAnswer((_) async {
          call++;
          if (call == 2) {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return const Result.ok([adjei]); // the stale, slower response
          }
          return const Result.ok([mensah]);
        });
        return FindClinicianBloc(clinicianRepository: repository);
      },
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FindClinicianSpecialtyChanged('Cardiology'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const FindClinicianSpecialtyChanged('Pediatrics'));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      verify: (bloc) {
        expect(bloc.state.filter.specialty, 'Pediatrics');
        expect(bloc.state.clinicians, [mensah]);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'a failure is shown over the previous list, never instead of it',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        when(() => repository.search(any()))
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        bloc.add(const FindClinicianRetried());
      },
      verify: (bloc) {
        expect(bloc.state.status, FindClinicianStatus.ready);
        expect(bloc.state.failure, isA<NetworkFailure>());
        expect(bloc.state.clinicians, isNotEmpty);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        when(() => repository.search(any())).thenThrow(StateError('boom'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const FindClinicianStarted()),
      skip: 1,
      verify: (bloc) {
        // Same guard as HomeBloc: a screen must never hang on its spinner.
        expect(bloc.state.status, FindClinicianStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );

    blocTest<FindClinicianBloc, FindClinicianState>(
      'an empty result with filters on is not treated as an error',
      build: () {
        when(() => repository.search(any()))
            .thenAnswer((_) async => const Result.ok([]));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const FindClinicianStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FindClinicianSpecialtyChanged('Neurology'));
      },
      verify: (bloc) {
        // "Nobody practices that here" and "the request failed" need
        // different screens.
        expect(bloc.state.isEmptyBecauseOfFilters, isTrue);
        expect(bloc.state.failure, isNull);
      },
    );

    test('the filter builds only query params the backend really has', () {
      expect(const ClinicianFilter().toQuery(), isEmpty);
      expect(
        const ClinicianFilter(specialty: ' Cardio ', onlineOnly: true).toQuery(),
        {'specialty': 'Cardio', 'online': 'true'},
      );
      // ?online=false returns only offline clinicians, so it is never sent.
      expect(
        const ClinicianFilter(specialty: 'Cardio').toQuery(),
        isNot(contains('online')),
      );
    });
  });
}

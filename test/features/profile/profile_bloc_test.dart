import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/profile/data/django_profile_repository.dart';
import 'package:carelite_app/features/profile/data/profile_repository.dart';
import 'package:carelite_app/features/profile/domain/patient_account.dart';
import 'package:carelite_app/features/profile/domain/patient_profile.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_event.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

void main() {
  group('DjangoProfileRepository.fetchAccount', () {
    late _MockApiClient client;
    late DjangoProfileRepository repository;

    setUp(() {
      client = _MockApiClient();
      repository = DjangoProfileRepository(client);
    });

    test('reads the user row and the patient profile together', () async {
      when(() => client.get(ApiContract.currentUser)).thenAnswer(
        (_) async => _response(200, {
          'id': '5f91f5d2', 'username': 'kofi', 'email': 'kofi@example.gh',
          'role': 'PATIENT', 'phone': '+233201000000',
        }),
      );
      when(() => client.get(ApiContract.patientProfile)).thenAnswer(
        (_) async => _response(200, {
          'date_of_birth': '1990-03-12', 'sex': 'MALE',
          'blood_group': 'O+', 'allergies': 'penicillin',
          'emergency_flag': false,
        }),
      );

      final result = await repository.fetchAccount();

      final account = result.when(ok: (a) => a, err: (f) => throw f);
      expect(account.username, 'kofi');
      expect(account.dateOfBirthLabel, '12 Mar 1990');
      expect(account.sex, Gender.male);
      expect(account.bloodGroup, 'O+');
      expect(account.allergies, 'penicillin');
    });

    test('still returns the account when there is no patient-profile row',
        () async {
      // Failing the whole screen for a missing profile row would lock the
      // user out of sign-out, which lives on it.
      when(() => client.get(ApiContract.currentUser)).thenAnswer(
        (_) async => _response(200, {'id': '1', 'username': 'kofi'}),
      );
      when(() => client.get(ApiContract.patientProfile))
          .thenAnswer((_) async => _response(404, {'detail': 'Not found.'}));

      final result = await repository.fetchAccount();

      final account = result.when(ok: (a) => a, err: (f) => throw f);
      expect(account.username, 'kofi');
      expect(account.dateOfBirth, isNull);
      expect(account.bloodGroup, isNull);
    });

    test('a 401 says the session expired rather than "went wrong"', () async {
      when(() => client.get(ApiContract.currentUser))
          .thenAnswer((_) async => _response(401, null));
      when(() => client.get(ApiContract.patientProfile))
          .thenAnswer((_) async => _response(401, null));

      final result = await repository.fetchAccount();

      expect(result.when(ok: (_) => null, err: (f) => f), isA<AuthFailure>());
    });
  });

  group('PatientAccount', () {
    test('age is computed from the clock, never stored', () {
      final account = PatientAccount(
        id: '1',
        username: 'kofi',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
      );
      expect(account.age, isNotNull);
      expect(account.age! >= 29 && account.age! <= 30, isTrue);
    });

    test('a birthday later this year has not happened yet', () {
      final now = DateTime.now();
      final account = PatientAccount(
        id: '1',
        username: 'kofi',
        dateOfBirth: DateTime(now.year - 20, now.month, now.day)
            .add(const Duration(days: 1)),
      );
      expect(account.age, 19);
    });

    test('an empty username still yields an avatar initial', () {
      expect(const PatientAccount(id: '1', username: '').initials, '?');
      expect(const PatientAccount(id: '1', username: 'kofi').initials, 'K');
    });
  });

  group('ProfileBloc', () {
    late _MockProfileRepository repository;

    const account = PatientAccount(id: '1', username: 'kofi');

    setUp(() {
      repository = _MockProfileRepository();
      when(() => repository.fetchAccount())
          .thenAnswer((_) async => const Result.ok(account));
    });

    blocTest<ProfileBloc, ProfileState>(
      'loads the account',
      build: () => ProfileBloc(profileRepository: repository),
      act: (bloc) => bloc.add(const ProfileStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, ProfileStatus.ready);
        expect(bloc.state.account, account);
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      'a failure still reaches ready, so sign-out stays reachable',
      build: () {
        when(() => repository.fetchAccount())
            .thenAnswer((_) async => const Result.err(NetworkFailure()));
        return ProfileBloc(profileRepository: repository);
      },
      act: (bloc) => bloc.add(const ProfileStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, ProfileStatus.ready);
        expect(bloc.state.failure, isA<NetworkFailure>());
      },
    );

    blocTest<ProfileBloc, ProfileState>(
      'reaches ready with a failure even if the repository throws outright',
      build: () {
        when(() => repository.fetchAccount()).thenThrow(StateError('boom'));
        return ProfileBloc(profileRepository: repository);
      },
      act: (bloc) => bloc.add(const ProfileStarted()),
      skip: 1,
      verify: (bloc) {
        expect(bloc.state.status, ProfileStatus.ready);
        expect(bloc.state.failure, isNotNull);
      },
    );
  });
}

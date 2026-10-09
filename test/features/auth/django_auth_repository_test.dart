import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/api/token_store.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/auth/data/django_auth_repository.dart';
import 'package:carelite_app/features/auth/domain/auth_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStore extends Mock implements TokenStore {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

void main() {
  late _MockApiClient client;
  late _MockTokenStore tokenStore;
  late DjangoAuthRepository repository;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    client = _MockApiClient();
    tokenStore = _MockTokenStore();
    when(() => client.onSessionExpired).thenAnswer((_) => const Stream.empty());
    when(() => tokenStore.hasSession).thenAnswer((_) async => false);
    when(() => tokenStore.clear()).thenAnswer((_) async {});
    when(() => tokenStore.save(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'),
        )).thenAnswer((_) async {});
    repository = DjangoAuthRepository(client: client, tokenStore: tokenStore);
  });

  tearDown(() => repository.dispose());

  group('phone + OTP (not shipped on the backend)', () {
    test('sendOtp reports NotImplemented rather than a fake success',
        () async {
      // A stub that returned Result.ok would walk the patient into an OTP
      // screen with no code ever arriving and no session behind it.
      final result = await repository.sendOtp('+233241234567');

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<NotImplementedFailure>());
      verifyNever(() => client.post(any(), data: any(named: 'data')));
    });

    test('verifyOtp never fabricates a session', () async {
      final result =
          await repository.verifyOtp(phoneNumber: '+233241234567', otp: '123456');

      expect(result.when(ok: (_) => null, err: (f) => f),
          isA<NotImplementedFailure>());
      // Nothing was written to secure storage — no token, real or invented.
      verifyNever(() => tokenStore.save(
            access: any(named: 'access'),
            refresh: any(named: 'refresh'),
          ));
    });
  });

  group('signInWithPassword', () {
    test('stores the token pair and returns the user on success', () async {
      when(() => client.post(ApiContract.tokenObtain,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async =>
              _response(200, {'access': 'a-token', 'refresh': 'r-token'}));
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {
            'id': 7,
            'username': 'esi@example.com',
            'email': 'esi@example.com',
            'phone': '+233241234567',
            'role': 'PATIENT',
          }));
      when(() => client.get(ApiContract.patientProfile)).thenAnswer(
          (_) async => _response(200, {'date_of_birth': null}));

      final result = await repository.signInWithPassword(
        email: 'esi@example.com',
        password: 'hunter2',
      );

      final user = result.when(ok: (u) => u, err: (_) => null);
      expect(user?.id, '7');
      expect(user?.phone, '+233241234567');
      // Carried on the record for callers that want it (e.g. Home's avatar
      // fallback) — but never shown as-is; see [formatUsername].
      expect(user?.username, 'esi@example.com');
      // Verified: this backend has no name field anywhere (User has no
      // first_name/last_name in the serializer; PatientProfile has none
      // either) — fullName must not be invented from username or elsewhere.
      expect(user?.fullName, isNull);
      verify(() => tokenStore.save(access: 'a-token', refresh: 'r-token'))
          .called(1);
    });

    test('maps 401 to a readable auth failure, not a raw body', () async {
      when(() => client.post(ApiContract.tokenObtain,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _response(
              401, {'detail': 'No active account found with the given credentials'}));

      final result = await repository.signInWithPassword(
        email: 'esi@example.com',
        password: 'wrong',
      );

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<AuthFailure>());
      expect(failure!.message, 'Incorrect email or password.');
      verifyNever(() => tokenStore.save(
            access: any(named: 'access'),
            refresh: any(named: 'refresh'),
          ));
    });

    test('rejects a 200 that is missing the access token', () async {
      // Guards the assumed response shape: if the backend answers 200 with
      // something else, the app must not treat it as signed in.
      when(() => client.post(ApiContract.tokenObtain,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _response(200, {'unexpected': true}));

      final result = await repository.signInWithPassword(
        email: 'esi@example.com',
        password: 'hunter2',
      );

      expect(result.when(ok: (_) => null, err: (f) => f),
          isA<UnexpectedFailure>());
      verifyNever(() => tokenStore.save(
            access: any(named: 'access'),
            refresh: any(named: 'refresh'),
          ));
    });

    test('posts the credential under the configured field name', () async {
      when(() => client.post(ApiContract.tokenObtain,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async =>
              _response(200, {'access': 'a', 'refresh': 'r'}));
      when(() => client.get(ApiContract.currentUser))
          .thenAnswer((_) async => _response(200, {'id': 1}));

      await repository.signInWithPassword(
        email: 'esi@example.com',
        password: 'hunter2',
      );

      // simplejwt posts USERNAME_FIELD; which key that is was not verifiable
      // against the backend, so it lives in one constant. This test pins the
      // wire format to that constant so a change is deliberate.
      final captured = verify(() => client.post(ApiContract.tokenObtain,
          data: captureAny(named: 'data'),
          options: any(named: 'options'))).captured.single as Map;
      expect(captured.containsKey(ApiContract.credentialField), isTrue);
      expect(captured['password'], 'hunter2');
    });
  });

  group('registerWithEmail', () {
    test('surfaces a missing endpoint as NotImplemented, not a user error',
        () async {
      // The register path is an assumption. A 404 means "we guessed wrong",
      // which must not be reported as bad account details.
      when(() => client.post(ApiContract.register,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _response(404, {'detail': 'Not found.'}));

      final result = await repository.registerWithEmail(
        email: 'esi@example.com',
        password: 'hunter2',
        phone: '+233241234567',
      );

      expect(result.when(ok: (_) => null, err: (f) => f),
          isA<NotImplementedFailure>());
    });

    test('falls back to signing in when register returns no tokens', () async {
      when(() => client.post(ApiContract.register,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _response(201, {'id': 7}));
      when(() => client.post(ApiContract.tokenObtain,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async =>
              _response(200, {'access': 'a', 'refresh': 'r'}));
      when(() => client.get(ApiContract.currentUser))
          .thenAnswer((_) async => _response(200, {'id': 7}));

      final result = await repository.registerWithEmail(
        email: 'esi@example.com',
        password: 'hunter2',
        phone: '+233241234567',
      );

      expect(result.when(ok: (u) => u, err: (_) => null), isNotNull);
      verify(() => client.post(ApiContract.tokenObtain,
          data: any(named: 'data'), options: any(named: 'options'))).called(1);
    });

    test('sends email, password and phone together', () async {
      when(() => client.post(ApiContract.register,
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async =>
              _response(201, {'access': 'a', 'refresh': 'r'}));
      when(() => client.get(ApiContract.currentUser))
          .thenAnswer((_) async => _response(200, {'id': 7}));

      await repository.registerWithEmail(
        email: 'esi@example.com',
        password: 'hunter2',
        phone: '+233241234567',
      );

      final body = verify(() => client.post(ApiContract.register,
          data: captureAny(named: 'data'),
          options: any(named: 'options'))).captured.single as Map;
      expect(body['email'], 'esi@example.com');
      expect(body['password'], 'hunter2');
      expect(body['phone'], '+233241234567');
    });
  });

  group('profile completeness (derived — the backend has no such field)', () {
    test('a patient with a date of birth on file counts as complete',
        () async {
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '1', 'role': 'PATIENT'}));
      when(() => client.get(ApiContract.patientProfile)).thenAnswer(
          (_) async => _response(200, {'date_of_birth': '2001-01-01'}));
      when(() => tokenStore.hasSession).thenAnswer((_) async => true);

      final user = await repository.authStateChanges().first;

      expect(user?.hasCompletedProfile, isTrue);
    });

    test('a patient with no date of birth is not yet complete', () async {
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '1', 'role': 'PATIENT'}));
      when(() => client.get(ApiContract.patientProfile)).thenAnswer(
          (_) async => _response(200, {'date_of_birth': null}));
      when(() => tokenStore.hasSession).thenAnswer((_) async => true);

      final user = await repository.authStateChanges().first;

      expect(user?.hasCompletedProfile, isFalse);
    });

    test('a non-patient role never reaches the completeness check — the '
        'session is refused before that matters', () async {
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '1', 'role': 'CLINICIAN'}));
      when(() => tokenStore.hasSession).thenAnswer((_) async => true);

      final user = await repository.authStateChanges().first;

      expect(user, isNull);
      verifyNever(() => client.get(ApiContract.patientProfile));
    });

    test('a failed completeness check re-shows the funnel rather than '
        'skipping it — safe because that screen is idempotent', () async {
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '1', 'role': 'PATIENT'}));
      when(() => client.get(ApiContract.patientProfile))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/')));
      when(() => tokenStore.hasSession).thenAnswer((_) async => true);

      final user = await repository.authStateChanges().first;

      expect(user?.hasCompletedProfile, isFalse);
    });
  });

  group('CareLite is a patient app', () {
    test('a clinician signing in is refused, with a reason', () async {
      // Every screen here is patient-scoped and booking is IsPatient-only
      // server-side. Letting a clinician in produced a dashboard that looked
      // functional and then failed on every action.
      when(() => client.post(
            ApiContract.tokenObtain,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _response(200, {
            'access': 'a', 'refresh': 'r', 'role': 'CLINICIAN',
          }));
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '9', 'role': 'CLINICIAN'}));

      final result = await repository.signInWithPassword(
        email: 'dr_adjei',
        password: 'carelite123',
      );

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<AuthFailure>());
      expect(failure!.message, contains('not a patient account'));
    });

    test('a refused sign-in leaves no usable session behind it', () async {
      when(() => client.post(
            ApiContract.tokenObtain,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _response(200, {
            'access': 'a', 'refresh': 'r', 'role': 'CLINICIAN',
          }));
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '9', 'role': 'CLINICIAN'}));

      await repository.signInWithPassword(
        email: 'dr_adjei',
        password: 'carelite123',
      );

      // The tokens were saved by the successful token call — they must be
      // cleared again, or the app would restore the rejected account on the
      // next cold start.
      verify(() => tokenStore.clear()).called(greaterThan(0));
    });

    test('a patient signs in normally', () async {
      when(() => client.post(
            ApiContract.tokenObtain,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _response(200, {
            'access': 'a', 'refresh': 'r', 'role': 'PATIENT',
          }));
      when(() => client.get(ApiContract.currentUser)).thenAnswer((_) async =>
          _response(200, {'id': '1', 'role': 'PATIENT'}));
      when(() => client.get(ApiContract.patientProfile)).thenAnswer(
          (_) async => _response(200, {'date_of_birth': '2001-01-01'}));

      final result = await repository.signInWithPassword(
        email: 'kofi',
        password: 'carelite123',
      );

      expect(result.when(ok: (u) => u.role, err: (_) => null), AppRole.patient);
    });
  });

  group('signOut', () {
    test('clears the stored pair', () async {
      await repository.signOut();
      verify(() => tokenStore.clear()).called(1);
    });
  });
}

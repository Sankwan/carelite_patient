import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/profile/data/django_profile_repository.dart';
import 'package:carelite_app/features/profile/domain/emergency_contact.dart';
import 'package:carelite_app/features/profile/domain/patient_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

void main() {
  late _MockApiClient client;
  late DjangoProfileRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoProfileRepository(client);
  });

  test('sends date_of_birth, sex and blood_group to the verified endpoint',
      () async {
    when(() => client.patch(ApiContract.patientProfile,
            data: any(named: 'data')))
        .thenAnswer((_) async => _response(200, {'id': 11}));

    final profile = PatientProfile(
      fullName: 'Esi Owusu',
      dateOfBirth: DateTime(2001),
      gender: Gender.female,
      bloodType: BloodType.oPositive,
      emergencyContact: const EmergencyContact(name: 'Kwame', phone: '+233...'),
    );

    final result = await repository.saveProfile(userId: 'u1', profile: profile);

    expect(result.when(ok: (_) => true, err: (_) => false), isTrue);
    final body = verify(() => client.patch(ApiContract.patientProfile,
        data: captureAny(named: 'data'))).captured.single as Map;
    expect(body['date_of_birth'], '2001-01-01');
    expect(body['sex'], 'FEMALE');
    expect(body['blood_group'], 'O+');
    // Verified: PatientProfileSerializer has no full_name and no emergency
    // contact name/phone field (only a differently-meaning boolean
    // emergency_flag) — there is nowhere to send them, so this must never
    // silently invent keys the backend will ignore or 400 on.
    expect(body.containsKey('full_name'), isFalse);
    expect(body.containsKey('emergency_contact_name'), isFalse);
    expect(body.containsKey('emergency_contact_phone'), isFalse);
  });

  test('maps "prefer not to say" to the backend UNKNOWN choice', () async {
    when(() => client.patch(ApiContract.patientProfile,
            data: any(named: 'data')))
        .thenAnswer((_) async => _response(200, <String, dynamic>{}));

    await repository.saveProfile(
      userId: 'u1',
      profile: const PatientProfile(
        fullName: 'Esi',
        gender: Gender.preferNotToSay,
      ).copyWith(dateOfBirth: DateTime(2000)),
    );

    final body = verify(() => client.patch(ApiContract.patientProfile,
        data: captureAny(named: 'data'))).captured.single as Map;
    expect(body['sex'], 'UNKNOWN');
  });

  test('a validation error surfaces the field message, not a generic string',
      () async {
    when(() => client.patch(ApiContract.patientProfile,
            data: any(named: 'data')))
        .thenAnswer((_) async => _response(400, {
              'date_of_birth': ['Date has wrong format.']
            }));

    final result = await repository.saveProfile(
      userId: 'u1',
      profile: PatientProfile(
        fullName: 'Esi',
        dateOfBirth: DateTime(2001),
      ),
    );

    final failure = result.when(ok: (_) => null, err: (f) => f);
    expect(failure!.message, 'Date has wrong format.');
  });

  test('a connectivity failure is reported as NetworkFailure', () async {
    when(() => client.patch(ApiContract.patientProfile,
            data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    ));

    final result = await repository.saveProfile(
      userId: 'u1',
      profile: PatientProfile(
        fullName: 'Esi',
        dateOfBirth: DateTime(2001),
      ),
    );

    expect(result.when(ok: (_) => null, err: (f) => f), isA<NetworkFailure>());
  });
}

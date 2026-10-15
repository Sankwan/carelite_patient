import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/medical_records/data/django_vitals_repository.dart';
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
  late DjangoVitalsRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoVitalsRepository(
      client,
      currentUserId: () async => 'patient-uuid',
    );
  });

  test('reads the trend oldest-first, as the server sends it', () async {
    when(() => client.get(ApiContract.patientVitals('patient-uuid'))).thenAnswer(
      (_) async => _response(200, [
        {
          'id': 1,
          'recorded_by_username': 'dr_adjei',
          'recorded_at': '2026-09-01T10:00:00Z',
          'bmi': 22.9,
          'systolic': 118,
          'diastolic': 76,
          'temperature': '36.6',
          'pulse': 72,
          'respiratory_rate': 16,
          'spo2': 98,
          'weight_kg': '70.00',
          'height_cm': '175.00',
          'blood_glucose': null,
        },
      ]),
    );

    final result = await repository.fetchTrend();

    final record = result.when(ok: (v) => v.single, err: (f) => throw f);
    expect(record.bloodPressureLabel, '118/76');
    expect(record.bmi, 22.9);
    expect(record.weightKg, 70.0);
    expect(record.bloodGlucose, isNull);
  });

  test('an empty trend is not an error', () async {
    when(() => client.get(ApiContract.patientVitals('patient-uuid')))
        .thenAnswer((_) async => _response(200, <dynamic>[]));

    final result = await repository.fetchTrend();

    expect(result.when(ok: (v) => v, err: (_) => null), isEmpty);
  });

  test('a server failure is a network failure', () async {
    when(() => client.get(ApiContract.patientVitals('patient-uuid')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '/')));

    final result = await repository.fetchTrend();

    expect(result.when(ok: (_) => null, err: (f) => f), isA<NetworkFailure>());
  });

  test('with no known identity, it fails rather than guessing', () async {
    final anonymous = DjangoVitalsRepository(client, currentUserId: () async => null);

    final result = await anonymous.fetchTrend();

    expect(result.when(ok: (_) => false, err: (_) => true), isTrue);
    verifyNever(() => client.get(any()));
  });
}

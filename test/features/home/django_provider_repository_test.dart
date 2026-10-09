import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/home/data/django_provider_repository.dart';
import 'package:carelite_app/features/home/domain/provider.dart';
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
  late DjangoProviderRepository repository;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    client = _MockApiClient();
    repository = DjangoProviderRepository(client);
  });

  group('clinicians — verified live: no lat/lng on ClinicianProfile at all',
      () {
    test('fetchVerified parses DecimalFields serialized as strings',
        () async {
      // rating and consultation_fee come back as JSON strings ("4.80",
      // "160.00") — a Django DecimalField default, confirmed live. Parsing
      // them as num would throw.
      when(() => client.get(ApiContract.clinicians)).thenAnswer((_) async =>
          _response(200, {
            'results': [
              {
                'id': 5,
                'username': 'dr_adjei',
                'specialty': 'Cardiology',
                'bio': '',
                'years_experience': 6,
                'consultation_fee': '120.00',
                'is_online': true,
                'rating': '4.80',
              }
            ],
          }));

      final result = await repository.fetchVerified(kind: ProviderKind.clinician);

      final providers = result.when(ok: (list) => list, err: (_) => <Provider>[]);
      expect(providers.single.displayName, 'Dr. Adjei');
      expect(providers.single.rating, 4.80);
      expect(providers.single.consultationFee?.pesewas, 12000);
      expect(providers.single.distanceMetres, isNull);
    });

    test('fetchNearby ignores lat/lng for clinicians and hits the same '
        'endpoint as fetchVerified — there is nothing to rank by distance',
        () async {
      when(() => client.get(ApiContract.clinicians)).thenAnswer(
          (_) async => _response(200, {'results': <dynamic>[]}));

      await repository.fetchNearby(
        latitude: 5.5560,
        longitude: -0.1969,
        kind: ProviderKind.clinician,
      );

      verify(() => client.get(ApiContract.clinicians)).called(1);
      verifyNever(() => client.post(ApiContract.match, data: any(named: 'data')));
    });
  });

  group('facilities — verified live against POST /api/match/', () {
    test('fetchNearby converts distance_km to metres', () async {
      when(() => client.post(ApiContract.match, data: any(named: 'data')))
          .thenAnswer((_) async => _response(200, [
                {
                  'facility': {
                    'id': 8,
                    'name': 'Korle-Bu Lab',
                    'type': 'LAB',
                    'is_onboarded': true,
                  },
                  'distance_km': 1.65,
                  'stock_qty': null,
                },
              ]));

      final result = await repository.fetchNearby(
        latitude: 5.5560,
        longitude: -0.1969,
        kind: ProviderKind.lab,
      );

      final providers = result.when(ok: (list) => list, err: (_) => <Provider>[]);
      expect(providers.single.displayName, 'Korle-Bu Lab');
      expect(providers.single.distanceMetres, 1650);
    });

    test('sends the facility_type the backend expects, not the app enum name',
        () async {
      when(() => client.post(ApiContract.match, data: any(named: 'data')))
          .thenAnswer((_) async => _response(200, <dynamic>[]));

      await repository.fetchNearby(
        latitude: 5.5560,
        longitude: -0.1969,
        kind: ProviderKind.pharmacy,
      );

      final body = verify(() => client.post(ApiContract.match,
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['facility_type'], 'PHARMACY');
    });

    test('fetchVerified has no distance at all when there is no location',
        () async {
      when(() => client.get(ApiContract.facilities,
              query: any(named: 'query')))
          .thenAnswer((_) async => _response(200, {
                'results': [
                  {'id': 8, 'name': 'Korle-Bu Lab', 'type': 'LAB',
                   'is_onboarded': true},
                ],
              }));

      final result = await repository.fetchVerified(kind: ProviderKind.lab);

      final providers = result.when(ok: (list) => list, err: (_) => <Provider>[]);
      expect(providers.single.distanceMetres, isNull);
      expect(providers.single.distanceLabel, isNull);
    });
  });
}

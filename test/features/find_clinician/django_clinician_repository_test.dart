import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/features/find_clinician/data/django_clinician_repository.dart';
import 'package:carelite_app/features/find_clinician/domain/booking_request.dart';
import 'package:carelite_app/features/find_clinician/domain/search_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

/// Exactly as `accounts.serializers.PublicClinicianSerializer` returned it
/// from a live instance — note `rating` and `consultation_fee` are strings.
Map<String, dynamic> _clinicianRow({int id = 5, bool online = true}) => {
      'id': id,
      'username': 'dr_adjei',
      'specialty': 'Cardiology',
      'bio': 'Cardiology specialist based in Accra.',
      'years_experience': 6,
      'consultation_fee': '120.00',
      'is_online': online,
      'rating': '4.80',
    };

void main() {
  late _MockApiClient client;
  late DjangoClinicianRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoClinicianRepository(client);
  });

  group('search', () {
    test('parses the paginated envelope and the string decimals', () async {
      when(() => client.get(ApiContract.clinicians, query: any(named: 'query')))
          .thenAnswer((_) async => _response(200, {
                'count': 1,
                'next': null,
                'previous': null,
                'results': [_clinicianRow()],
              }));

      final result = await repository.search(const ClinicianFilter());

      final clinicians = result.when(ok: (v) => v, err: (f) => throw f);
      expect(clinicians.single.displayName, 'Dr. Adjei');
      // DecimalFields arrive as JSON strings; a numeric cast would throw.
      expect(clinicians.single.rating, 4.8);
      expect(clinicians.single.consultationFee?.pesewas, 12000);
      expect(clinicians.single.yearsExperience, 6);
    });

    test('sends specialty and online as the query params the backend has',
        () async {
      when(() => client.get(ApiContract.clinicians, query: any(named: 'query')))
          .thenAnswer((_) async => _response(200, {'results': <dynamic>[]}));

      await repository.search(
        const ClinicianFilter(specialty: 'Cardio', onlineOnly: true),
      );

      final captured = verify(() => client.get(
            ApiContract.clinicians,
            query: captureAny(named: 'query'),
          )).captured.single as Map<String, dynamic>?;
      expect(captured, {'specialty': 'Cardio', 'online': 'true'});
    });

    test('omits ?online entirely when the filter is off', () async {
      // `?online=false` is a real filter that returns only OFFLINE
      // clinicians — sending it unconditionally would hide everyone who is
      // actually available.
      when(() => client.get(ApiContract.clinicians, query: any(named: 'query')))
          .thenAnswer((_) async => _response(200, {'results': <dynamic>[]}));

      await repository.search(const ClinicianFilter(specialty: 'Cardio'));

      final captured = verify(() => client.get(
            ApiContract.clinicians,
            query: captureAny(named: 'query'),
          )).captured.single as Map<String, dynamic>?;
      expect(captured, isNot(contains('online')));
    });

    test('a malformed row is a visible failure, never an uncaught throw',
        () async {
      when(() => client.get(ApiContract.clinicians, query: any(named: 'query')))
          .thenAnswer((_) async => _response(200, {
                'results': [
                  _clinicianRow()..['rating'] = <String>[],
                ],
              }));

      final result = await repository.search(const ClinicianFilter());

      expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
    });
  });

  group('fetchSlots', () {
    test('parses the slot list and drops times that have already passed',
        () async {
      // The server generates slots from recurring weekly windows and does
      // not filter out earlier-today ones; offering 9:00 this morning at 3pm
      // would either 400 or book the past.
      final past = DateTime.now().subtract(const Duration(hours: 2));
      final future = DateTime.now().add(const Duration(hours: 2));
      when(() => client.get(
            ApiContract.clinicianSlots(5),
            query: any(named: 'query'),
          )).thenAnswer((_) async => _response(200, {
            'clinician': 5,
            'slots': [
              past.toUtc().toIso8601String(),
              future.toUtc().toIso8601String(),
            ],
          }));

      final result = await repository.fetchSlots(5);

      final slots = result.when(ok: (v) => v, err: (f) => throw f);
      expect(slots, hasLength(1));
      expect(slots.single.isAfter(DateTime.now()), isTrue);
    });

    test('an empty slot list is a real answer, not a failure', () async {
      // A clinician with no availability windows must reach the UI as "no
      // times", which offers on-demand — not as an error toast.
      when(() => client.get(
            ApiContract.clinicianSlots(5),
            query: any(named: 'query'),
          )).thenAnswer(
              (_) async => _response(200, {'clinician': 5, 'slots': <dynamic>[]}));

      final result = await repository.fetchSlots(5);

      expect(result.when(ok: (v) => v, err: (f) => throw f), isEmpty);
    });

    test('a 404 says the clinician is gone rather than "something went wrong"',
        () async {
      when(() => client.get(
            ApiContract.clinicianSlots(999),
            query: any(named: 'query'),
          )).thenAnswer((_) async =>
              _response(404, {'detail': 'Clinician not found.'}));

      final result = await repository.fetchSlots(999);

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure!.message, contains('no longer available'));
    });
  });

  group('book', () {
    test('posts `clinician`, not `clinician_id`', () async {
      // Verified live: `clinician_id` is silently ignored and the request
      // comes back {"clinician": ["Required for a SPECIFIC booking."]}.
      when(() => client.post(ApiContract.appointments, data: any(named: 'data')))
          .thenAnswer((_) async => _response(201, {
                'id': 13,
                'clinician': _clinicianRow(),
                'booking_type': 'SPECIFIC',
                'mode': 'SCHEDULED',
                'scheduled_at': '2026-09-10T10:00:00Z',
                'status': 'REQUESTED',
                'created_at': '2026-09-08T17:16:04Z',
              }));

      final result = await repository.book(
        BookingRequest.specific(
          clinicianId: 5,
          mode: BookingMode.scheduled,
          scheduledFor: DateTime.utc(2026, 9, 10, 10),
        ),
      );

      final body = verify(() => client.post(
            ApiContract.appointments,
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(body['clinician'], 5);
      expect(body.containsKey('clinician_id'), isFalse);
      expect(result.when(ok: (a) => a.id, err: (f) => throw f), '13');
    });

    test('an unmatched ANY booking surfaces the server\'s own reason',
        () async {
      // Live response: 400 {"detail": "No available certified clinician
      // matched this request."} — the patient can act on that; "something
      // went wrong" would leave them retrying forever.
      when(() => client.post(ApiContract.appointments, data: any(named: 'data')))
          .thenAnswer((_) async => _response(400, {
                'detail': 'No available certified clinician matched this request.',
              }));

      final result = await repository.book(
        BookingRequest.any(mode: BookingMode.onDemand),
      );

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<ValidationFailure>());
      expect(failure!.message, contains('No available certified clinician'));
    });

    test('a field validation error is read out of its list', () async {
      when(() => client.post(ApiContract.appointments, data: any(named: 'data')))
          .thenAnswer((_) async => _response(400, {
                'scheduled_at': ['Required for a SCHEDULED booking.'],
              }));

      final result = await repository.book(
        BookingRequest.specific(clinicianId: 5, mode: BookingMode.scheduled),
      );

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure!.message, 'Required for a SCHEDULED booking.');
    });

    test('never reports success without a 201', () async {
      when(() => client.post(ApiContract.appointments, data: any(named: 'data')))
          .thenAnswer((_) async => _response(200, {'id': 1}));

      final result = await repository.book(
        BookingRequest.any(mode: BookingMode.onDemand),
      );

      expect(result.when(ok: (_) => 'booked', err: (_) => null), isNull);
    });

    test('an ON_DEMAND booking sends a null scheduled_at and no clinician key '
        'for ANY', () async {
      when(() => client.post(ApiContract.appointments, data: any(named: 'data')))
          .thenAnswer((_) async => _response(400, {'detail': 'x'}));

      await repository.book(
        BookingRequest.any(mode: BookingMode.onDemand, specialty: 'Cardiology'),
      );

      final body = verify(() => client.post(
            ApiContract.appointments,
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(body['scheduled_at'], isNull);
      expect(body['booking_type'], 'ANY');
      expect(body['specialty'], 'Cardiology');
      expect(body.containsKey('clinician'), isFalse);
    });
  });
}

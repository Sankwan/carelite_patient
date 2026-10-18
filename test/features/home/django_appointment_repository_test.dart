import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/home/data/django_appointment_repository.dart';
import 'package:carelite_app/features/home/domain/appointment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

/// One item in the paginated {count, next, previous, results} envelope —
/// verified live against `appointments.serializers.AppointmentSerializer`.
Map<String, dynamic> _appointmentRow({
  required int id,
  required String status,
  required String scheduledAt,
  Map<String, dynamic>? clinician,
}) {
  return {
    'id': id,
    'patient_username': 'esi@example.com',
    'clinician': clinician ??
        {'id': 5, 'username': 'dr_adjei', 'specialty': 'Cardiology',
         'rating': '4.80', 'is_online': true},
    'booking_type': 'SPECIFIC',
    'mode': 'SCHEDULED',
    'scheduled_at': scheduledAt,
    'reason': 'Checkup',
    'status': status,
    'capture_lat': null,
    'capture_lng': null,
    'created_at': '2026-09-01T00:00:00Z',
    'updated_at': '2026-09-01T00:00:00Z',
  };
}

void main() {
  late _MockApiClient client;
  late DjangoAppointmentRepository repository;
  final now = DateTime.now();

  setUp(() {
    client = _MockApiClient();
    repository = DjangoAppointmentRepository(client);
  });

  test('unwraps the DRF pagination envelope, not a bare list', () async {
    // Verified live: PageNumberPagination wraps every list endpoint in
    // {count, next, previous, results} — a bare-array parse would throw.
    when(() => client.get(ApiContract.appointments)).thenAnswer((_) async =>
        _response(200, {
          'count': 1,
          'next': null,
          'previous': null,
          'results': [
            _appointmentRow(
              id: 9,
              status: 'CONFIRMED',
              scheduledAt: now.add(const Duration(hours: 2)).toIso8601String(),
            ),
          ],
        }));

    final result = await repository.fetchUpcoming('u1');

    final appointment = result.when(ok: (a) => a, err: (_) => null);
    expect(appointment?.id, '9');
    expect(appointment?.provider.displayName, 'Dr. Adjei');
    expect(appointment?.status, AppointmentStatus.confirmed);
  });

  test('a REQUESTED appointment counts as upcoming but is not joinable',
      () async {
    when(() => client.get(ApiContract.appointments)).thenAnswer((_) async =>
        _response(200, {
          'results': [
            _appointmentRow(
              id: 1,
              status: 'REQUESTED',
              scheduledAt: now.add(const Duration(days: 1)).toIso8601String(),
            ),
          ],
        }));

    final result = await repository.fetchUpcoming('u1');

    final appointment = result.when(ok: (a) => a, err: (_) => null);
    expect(appointment, isNotNull);
    expect(appointment!.isJoinable, isFalse);
  });

  test('fetchUpcoming ignores completed and cancelled appointments',
      () async {
    when(() => client.get(ApiContract.appointments)).thenAnswer((_) async =>
        _response(200, {
          'results': [
            _appointmentRow(
                id: 1, status: 'COMPLETED', scheduledAt: now.toIso8601String()),
            _appointmentRow(
                id: 2, status: 'CANCELLED', scheduledAt: now.toIso8601String()),
          ],
        }));

    final result = await repository.fetchUpcoming('u1');

    expect(result.when(ok: (a) => a, err: (_) => 'error'), isNull);
  });

  test('fetchRecent returns completed appointments newest first', () async {
    when(() => client.get(ApiContract.appointments)).thenAnswer((_) async =>
        _response(200, {
          'results': [
            _appointmentRow(
              id: 1, status: 'COMPLETED',
              scheduledAt: now.subtract(const Duration(days: 20)).toIso8601String(),
            ),
            _appointmentRow(
              id: 2, status: 'COMPLETED',
              scheduledAt: now.subtract(const Duration(days: 2)).toIso8601String(),
            ),
            _appointmentRow(
              id: 3, status: 'REQUESTED',
              scheduledAt: now.add(const Duration(days: 2)).toIso8601String(),
            ),
          ],
        }));

    final result = await repository.fetchRecent('u1');

    final recent = result.when(ok: (list) => list, err: (_) => <Appointment>[]);
    expect(recent.map((a) => a.id), ['2', '1']);
  });

  test('a null clinician renders as a labelled placeholder, not a crash',
      () async {
    // clinician is nullable server-side (SET_NULL, or a not-yet-matched ANY
    // booking) — verified from the model, not exercised live (booking
    // validation makes it rare), so this is the defensive path.
    when(() => client.get(ApiContract.appointments)).thenAnswer((_) async =>
        _response(200, {
          'results': [
            _appointmentRow(
              id: 4, status: 'REQUESTED',
              scheduledAt: now.add(const Duration(days: 1)).toIso8601String(),
            )..['clinician'] = null,
          ],
        }));

    final result = await repository.fetchUpcoming('u1');

    final appointment = result.when(ok: (a) => a, err: (_) => null);
    expect(appointment?.provider.displayName, 'Clinician unavailable');
  });

  test(
    'a null scheduled_at (a real ON_DEMAND booking, not malformed data) '
    'falls back to created_at instead of throwing',
    () async {
      // Regression test for the exact bug that shipped: an ON_DEMAND
      // booking's scheduled_at is null by design (Appointment.mode ON_DEMAND
      // clears it server-side). DateTime.parse(null as String) threw, went
      // uncaught through Future.wait, and left HomeBloc on
      // HomeStatus.loading forever with the real cause never shown.
      //
      // createdAt must be recent, not a fixed past date: fetchUpcoming
      // treats a pending appointment scheduled over a day in the past as
      // stale and correctly filters it out — a hardcoded date would silently
      // start failing this test the day it turns more than a day old.
      // Inside the 15-minute window, so it isn't treated as missed.
      final createdAt = now.subtract(const Duration(minutes: 5));
      when(() => client.get(ApiContract.appointments)).thenAnswer(
        (_) async => _response(200, {
          'results': [
            _appointmentRow(
              id: 7, status: 'CONFIRMED',
              scheduledAt: now.toIso8601String(),
            )
              ..['mode'] = 'ON_DEMAND'
              ..['scheduled_at'] = null
              ..['created_at'] = createdAt.toIso8601String(),
          ],
        }),
      );

      final result = await repository.fetchUpcoming('u1');

      final appointment = result.when(ok: (a) => a, err: (f) => throw f);
      expect(appointment, isNotNull);
      expect(appointment!.scheduledFor, createdAt.toLocal());
    },
  );

  test(
    'a row that fails to parse for any other reason is a visible failure, '
    'never a silent hang',
    () async {
      // created_at missing too — nothing left to fall back to, so this must
      // report a failure rather than propagate an uncaught exception.
      when(() => client.get(ApiContract.appointments)).thenAnswer(
        (_) async => _response(200, {
          'results': [
            _appointmentRow(
              id: 8, status: 'CONFIRMED',
              scheduledAt: now.toIso8601String(),
            )
              ..['scheduled_at'] = null
              ..['created_at'] = null,
          ],
        }),
      );

      final result = await repository.fetchUpcoming('u1');

      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isNotNull);
    },
  );
}

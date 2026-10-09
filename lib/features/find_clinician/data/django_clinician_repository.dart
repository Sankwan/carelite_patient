import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../../home/domain/appointment.dart';
import '../../home/domain/provider.dart';
import '../domain/booking_request.dart';
import '../domain/search_filter.dart';
import 'clinician_repository.dart';

/// Clinician browse, availability and booking against the Django API.
///
/// Every endpoint here was hit against a running instance of
/// github.com/campofo/carelite on 2026-09-08, including the failure paths:
/// an unmatched `ANY` booking (400 `{"detail": …}`), a SCHEDULED booking with
/// no time (400 `{"scheduled_at": [...]}`), an unknown clinician id (400
/// `{"clinician": [...]}`) and slots for a clinician that does not exist
/// (404). Those are the responses the messages below are written against.
class DjangoClinicianRepository implements ClinicianRepository {
  const DjangoClinicianRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Provider>>> search(ClinicianFilter filter) async {
    try {
      final response = await _client.get(
        ApiContract.clinicians,
        query: filter.toQuery().isEmpty ? null : filter.toQuery(),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return Result.err(_failureFor(response));
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      try {
        return Result.ok(
          results
              .cast<Map<String, dynamic>>()
              .map(Provider.fromClinicianJson)
              .toList(growable: false),
        );
      } catch (e) {
        // Parsing throws TypeError/FormatException, never DioException, so
        // the outer catch below would not see it — the gap that once left
        // Home spinning forever. See DjangoAppointmentRepository._fetchAll.
        return Result.err(UnexpectedFailure(
          'Could not read the clinician list (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<List<DateTime>>> fetchSlots(
    int clinicianId, {
    int days = 7,
  }) async {
    try {
      final response = await _client.get(
        ApiContract.clinicianSlots(clinicianId),
        query: {'days': '$days'},
      );
      if (response.statusCode == 404) {
        return const Result.err(
          UnexpectedFailure('That clinician is no longer available.'),
        );
      }
      if (response.statusCode != 200 || response.data is! Map) {
        return Result.err(_failureFor(response));
      }
      final slots = (response.data as Map)['slots'];
      if (slots is! List) return const Result.err(NetworkFailure());
      try {
        final parsed = slots
            .map((slot) => DateTime.parse(slot as String).toLocal())
            .toList()
          ..sort();
        // The server generates slots from recurring availability windows and
        // does not filter out ones that have already passed today; a time
        // picker offering 9:00 this morning at 3pm would 400 on booking, or
        // worse, quietly book the past.
        final now = DateTime.now();
        return Result.ok(
          parsed.where((slot) => slot.isAfter(now)).toList(growable: false),
        );
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read available times (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<Appointment>> book(BookingRequest request) async {
    try {
      final response = await _client.post(
        ApiContract.appointments,
        data: request.toJson(),
      );
      if (response.statusCode == 201 && response.data is Map) {
        try {
          return Result.ok(
            Appointment.fromDjangoJson(
              (response.data as Map).cast<String, dynamic>(),
            ),
          );
        } catch (e) {
          // The booking really was created — reporting a failure here would
          // send the patient back to book a second one. Say so plainly
          // instead, and let Home (which re-fetches) show the truth.
          return const Result.err(UnexpectedFailure(
            'Your appointment was booked, but we could not display it. '
            'Check Appointments.',
          ));
        }
      }
      return Result.err(_bookingFailure(response));
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  /// A booking rejection is almost always something the patient can act on
  /// ("no clinician matched", "pick a time"), so the server's own message is
  /// shown rather than a generic one.
  Failure _bookingFailure(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      return const AuthFailure('Please sign in again to book.');
    }
    if (status == 400) {
      return ValidationFailure(
        drfMessage(
          response.data,
          fallback: 'That booking could not be completed.',
        ),
      );
    }
    return _failureFor(response);
  }

  Failure _failureFor(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      return const AuthFailure('Your session has expired. Please sign in again.');
    }
    if (status >= 500) {
      return const NetworkFailure(
        'The server is having trouble. Please try again shortly.',
      );
    }
    return UnexpectedFailure(drfMessage(response.data));
  }
}

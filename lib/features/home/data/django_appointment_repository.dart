import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/appointment.dart';
import 'appointment_repository.dart';

/// Appointments against the Django API.
///
/// Verified live: `GET /api/appointments/` was hit against a running
/// instance of github.com/campofo/carelite after booking a real appointment,
/// and the paginated `{count, next, previous, results}` envelope (DRF's
/// `PageNumberPagination`, on by default — `REST_FRAMEWORK.
/// DEFAULT_PAGINATION_CLASS` in settings) came back exactly as read in code.
///
/// `AppointmentViewSet.get_queryset` already scopes the list to "my own"
/// server-side (patient: booked; clinician: assigned) and there is no
/// `?status=` filter (no django-filter wired up) — this repository fetches
/// the one page (20, the server's `PAGE_SIZE`) and filters upcoming/recent
/// client-side. A patient with more than 20 appointments would need the
/// endpoint to grow pagination support on this repository's side too; flagged
/// in docs/PROJECT_STATUS.md rather than silently truncating without note.
class DjangoAppointmentRepository implements AppointmentRepository {
  const DjangoAppointmentRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<Appointment?>> fetchUpcoming(String patientId) async {
    final result = await _fetchAll();
    return result.when(
      ok: (appointments) {
        final now = DateTime.now();
        final upcoming = appointments.where((appointment) {
          final isPending = appointment.status == AppointmentStatus.requested ||
              appointment.status == AppointmentStatus.confirmed ||
              appointment.status == AppointmentStatus.inProgress;
          // A REQUESTED/CONFIRMED appointment more than a day in the past
          // was never resolved (never started, never cancelled) — treat it
          // as stale rather than surfacing it as "upcoming" forever.
          final isRecent =
              appointment.scheduledFor.isAfter(now.subtract(const Duration(days: 1)));
          return isPending && isRecent;
        }).toList()
          ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
        return Result.ok(upcoming.isEmpty ? null : upcoming.first);
      },
      err: Result.err,
    );
  }

  @override
  Future<Result<List<Appointment>>> fetchRecent(
    String patientId, {
    int limit = 3,
  }) async {
    final result = await _fetchAll();
    return result.when(
      ok: (appointments) {
        final completed = appointments
            .where((a) => a.status == AppointmentStatus.completed)
            .toList()
          ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
        return Result.ok(completed.take(limit).toList(growable: false));
      },
      err: Result.err,
    );
  }

  @override
  Future<Result<List<Appointment>>> fetchAll() async {
    final result = await _fetchAll();
    return result.when(
      ok: (appointments) => Result.ok(
        appointments.toList()
          ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor)),
      ),
      err: Result.err,
    );
  }

  @override
  Future<Result<Appointment>> cancel(String appointmentId) async {
    final id = int.tryParse(appointmentId);
    if (id == null) {
      return const Result.err(
        UnexpectedFailure('That appointment could not be cancelled.'),
      );
    }
    try {
      final response = await _client.post(
        ApiContract.appointmentAction(id, 'cancel'),
      );
      if (response.statusCode == 200 && response.data is Map) {
        try {
          return Result.ok(
            Appointment.fromDjangoJson(
              (response.data as Map).cast<String, dynamic>(),
            ),
          );
        } catch (_) {
          // The cancel succeeded; only the echo back failed to parse. Saying
          // "could not cancel" here would push the patient to try again on
          // an appointment that is already cancelled.
          return const Result.err(UnexpectedFailure(
            'The appointment was cancelled, but we could not refresh it. '
            'Pull to refresh.',
          ));
        }
      }
      if (response.statusCode == 400 || response.statusCode == 403) {
        // e.g. "This appointment can no longer be cancelled." — the server's
        // own wording is the useful one.
        return Result.err(ValidationFailure(drfMessage(
          response.data,
          fallback: 'That appointment can no longer be cancelled.',
        )));
      }
      return const Result.err(NetworkFailure());
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  Future<Result<List<Appointment>>> _fetchAll() async {
    try {
      final response = await _client.getAllPages(ApiContract.appointments);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      try {
        // A second, narrower try: parsing every row is a pure-Dart step
        // (JSON → Appointment), not a network step, and a malformed or
        // unexpectedly-shaped row throws a plain TypeError/FormatException —
        // never a DioException, so the outer catch alone never saw it. That
        // gap is exactly what shipped: an ON_DEMAND booking's null
        // scheduled_at threw here, escaped uncaught through Future.wait, and
        // left HomeBloc stuck on HomeStatus.loading forever with no error
        // shown — a hang that looked like "the app is broken" with nothing
        // in the UI to say why. Catching it here turns that into a real,
        // visible failure instead.
        return Result.ok(
          results
              .cast<Map<String, dynamic>>()
              .map(Appointment.fromDjangoJson)
              .toList(growable: false),
        );
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read your appointments (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }
}

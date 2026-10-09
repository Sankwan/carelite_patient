import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/call_session.dart';
import '../domain/precall_checklist.dart';
import 'call_repository.dart';

/// Pre-call checklist and call lifecycle against the Django API.
///
/// Every path here was driven live end-to-end on 2026-09-09 — booked,
/// confirmed, both participants' checklist, initiated, accepted, polled,
/// ended — including the rejection paths this class translates into
/// `Failure`s. See docs/PROJECT_STATUS.md.
class DjangoCallRepository implements CallRepository {
  const DjangoCallRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<PrecallStatus>> fetchPrecallStatus(String appointmentId) async {
    final id = _parseId(appointmentId);
    if (id == null) return const Result.err(UnexpectedFailure());
    try {
      final response = await _client.get(ApiContract.appointmentPrecall(id));
      if (response.statusCode != 200 || response.data is! Map) {
        return Result.err(_failureFor(response));
      }
      try {
        return Result.ok(PrecallStatus.fromDjangoJson(
          (response.data as Map).cast<String, dynamic>(),
        ));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read the pre-call checklist (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<PrecallStatus>> submitPrecallChecklist(
    String appointmentId,
    PrecallChecklist checklist,
  ) async {
    final id = _parseId(appointmentId);
    if (id == null) return const Result.err(UnexpectedFailure());
    try {
      final response = await _client.post(
        ApiContract.appointmentPrecall(id),
        data: checklist.toJson(),
      );
      if (response.statusCode != 200) {
        return Result.err(_failureFor(response));
      }
      // The POST response is just this user's own ack row, not the full
      // {you_acknowledged, can_join, both_ready} shape — re-fetch so the
      // caller sees whether the *other* participant is ready too.
      return fetchPrecallStatus(appointmentId);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<CallSession>> initiateCall(
    String appointmentId,
    CallMode mode,
  ) async {
    final id = _parseId(appointmentId);
    if (id == null) return const Result.err(UnexpectedFailure());
    try {
      final response = await _client.post(
        ApiContract.appointmentCall(id),
        data: {'mode': mode == CallMode.voice ? 'VOICE' : 'VIDEO'},
      );
      return _sessionFrom(response, successStatus: 201);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<CallSession>> fetchCall(String callId) async {
    final id = _parseId(callId);
    if (id == null) return const Result.err(UnexpectedFailure());
    try {
      final response = await _client.get(ApiContract.call(id));
      return _sessionFrom(response, successStatus: 200);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<CallSession>> endCall(String callId) async {
    final id = _parseId(callId);
    if (id == null) return const Result.err(UnexpectedFailure());
    try {
      final response =
          await _client.post(ApiContract.callAction(id, 'end'));
      return _sessionFrom(response, successStatus: 200);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  Result<CallSession> _sessionFrom(
    Response<dynamic> response, {
    required int successStatus,
  }) {
    if (response.statusCode != successStatus || response.data is! Map) {
      return Result.err(_failureFor(response));
    }
    try {
      return Result.ok(CallSession.fromDjangoJson(
        (response.data as Map).cast<String, dynamic>(),
      ));
    } catch (e) {
      return Result.err(UnexpectedFailure(
        'Could not read the call (${e.runtimeType}).',
      ));
    }
  }

  int? _parseId(String raw) => int.tryParse(raw);

  /// 403 here is almost always "you haven't done your own checklist yet" —
  /// worth the server's exact wording rather than a generic message. A 400
  /// on `end`/`accept` (e.g. "already ended") comes back as a bare JSON
  /// list, not `{detail: ...}` — `drfMessage` already reads both shapes.
  Failure _failureFor(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 401) {
      return const AuthFailure('Your session has expired. Please sign in again.');
    }
    if (status == 403) {
      return ValidationFailure(drfMessage(
        response.data,
        fallback: 'Complete the pre-call checklist before joining.',
      ));
    }
    if (status == 400) {
      return ValidationFailure(drfMessage(response.data));
    }
    if (status >= 500) {
      return const NetworkFailure(
        'The server is having trouble. Please try again shortly.',
      );
    }
    return UnexpectedFailure(drfMessage(response.data));
  }
}

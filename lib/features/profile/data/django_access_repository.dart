import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/api/drf_error.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/access_request.dart';
import 'access_repository.dart';

/// Record-access consent against the Django API's `access` app.
///
/// `GET /api/access-requests/` is scoped to the caller server-side: a
/// patient sees only requests made about them, so there is no patient id
/// to pass. The three actions (`approve`, `decline`, `revoke`) share one
/// endpoint shape, `POST /api/access-requests/{id}/{action}/`.
class DjangoAccessRepository implements AccessRepository {
  const DjangoAccessRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<AccessRequest>>> fetchRequests() async {
    try {
      final response = await _client.getAllPages(ApiContract.accessRequests);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      try {
        return Result.ok(
          results
              .cast<Map<String, dynamic>>()
              .map(AccessRequest.fromDjangoJson)
              .toList(growable: false),
        );
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read your access requests (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<AccessRequest>> approve(String requestId) =>
      _decide(requestId, 'approve');

  @override
  Future<Result<AccessRequest>> decline(String requestId) =>
      _decide(requestId, 'decline');

  @override
  Future<Result<AccessRequest>> revoke(String requestId) =>
      _decide(requestId, 'revoke');

  Future<Result<AccessRequest>> _decide(String requestId, String action) async {
    try {
      final response = await _client.post(
        ApiContract.accessRequestAction(requestId, action),
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return Result.err(UnexpectedFailure(drfMessage(response.data)));
      }
      try {
        return Result.ok(AccessRequest.fromDjangoJson(
          (response.data as Map).cast<String, dynamic>(),
        ));
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read the updated request (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }
}

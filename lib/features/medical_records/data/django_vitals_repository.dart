import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/vitals_record.dart';
import 'vitals_repository.dart';

/// Vitals against the Django API's `vitals` app.
///
/// `GET /api/patients/{id}/vitals/` returns a bare list (no pagination
/// envelope), oldest first, and a patient may read their own.
class DjangoVitalsRepository implements VitalsRepository {
  DjangoVitalsRepository(
    this._client, {
    required Future<String?> Function() currentUserId,
  }) : _currentUserId = currentUserId;

  final ApiClient _client;
  final Future<String?> Function() _currentUserId;

  @override
  Future<Result<List<VitalsRecord>>> fetchTrend() async {
    final patientId = await _currentUserId();
    if (patientId == null || patientId.isEmpty) {
      return const Result.err(
        UnexpectedFailure('Could not tell who you are signed in as.'),
      );
    }
    try {
      final response = await _client.get(ApiContract.patientVitals(patientId));
      if (response.statusCode != 200 || response.data is! List) {
        return const Result.err(NetworkFailure());
      }
      try {
        return Result.ok(
          (response.data as List)
              .cast<Map<String, dynamic>>()
              .map(VitalsRecord.fromDjangoJson)
              .toList(growable: false),
        );
      } catch (e) {
        return Result.err(UnexpectedFailure(
          'Could not read your vitals (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }
}

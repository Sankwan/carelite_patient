import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/provider.dart';
import 'provider_repository.dart';

/// Clinicians, labs, imaging centers and pharmacies against the Django API.
///
/// Two genuinely different backends live behind this one interface, verified
/// separately against a running instance of github.com/campofo/carelite:
///
/// * **Clinicians** — `GET /api/accounts/clinicians/`
///   (`VerifiedClinicianListView`). Already server-side filtered to
///   `verification_status=VERIFIED` and ordered `-rating`. There is no
///   lat/lng on `ClinicianProfile` at all — consultations are virtual, so
///   the backend has nothing to rank by distance. [fetchNearby] and
///   [fetchVerified] therefore do the *same* thing for clinicians: the
///   `latitude`/`longitude` arguments are accepted (interface compatibility
///   with the facility path) and ignored, not silently misapplied.
///
/// * **Labs / imaging / pharmacies** — `POST /api/match/` when a location is
///   known (real haversine `distance_km`, verified against a running match
///   for a LAB near Osu, Accra), or `GET /api/facilities/` when it is not
///   (no distance field at all — not "unknown", genuinely absent from that
///   response).
class DjangoProviderRepository implements ProviderRepository {
  const DjangoProviderRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Provider>>> fetchNearby({
    required double latitude,
    required double longitude,
    ProviderKind? kind,
    int radiusMetres = 20000,
    int limit = 20,
  }) async {
    if (kind == null || kind == ProviderKind.clinician) {
      return fetchVerified(kind: kind, limit: limit);
    }
    try {
      final response = await _client.post(
        ApiContract.match,
        data: {
          'facility_type': _facilityTypeFor(kind),
          'lat': latitude,
          'lng': longitude,
          'limit': limit.clamp(1, 20),
        },
      );
      if (response.statusCode != 200 || response.data is! List) {
        return const Result.err(NetworkFailure());
      }
      final rows = response.data as List;
      return _parse(rows, Provider.fromFacilityMatchJson);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<List<Provider>>> fetchVerified({
    ProviderKind? kind,
    int limit = 20,
  }) async {
    if (kind == null || kind == ProviderKind.clinician) {
      return _fetchClinicians(limit: limit);
    }
    try {
      final response = await _client.get(
        ApiContract.facilities,
        query: {'type': _facilityTypeFor(kind)},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      return _parse(results, Provider.fromFacilityJson, limit: limit);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  Future<Result<List<Provider>>> _fetchClinicians({required int limit}) async {
    try {
      final response = await _client.get(ApiContract.clinicians);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      return _parse(results, Provider.fromClinicianJson, limit: limit);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  /// A malformed or unexpectedly-shaped row throws a plain
  /// TypeError/FormatException from inside the mapper, never a
  /// DioException — the only kind the callers' outer catch is written for.
  /// An uncaught one of these escapes silently through HomeBloc's
  /// Future.wait and leaves Home stuck on its loading spinner forever (this
  /// exact failure mode shipped once already, from the appointment
  /// repository's identical gap — see DjangoAppointmentRepository._fetchAll).
  Result<List<Provider>> _parse(
    List<dynamic> rows,
    Provider Function(Map<String, dynamic>) mapper, {
    int? limit,
  }) {
    try {
      final mapped = rows.cast<Map<String, dynamic>>().map(mapper);
      final list = limit == null ? mapped.toList() : mapped.take(limit).toList();
      return Result.ok(List.unmodifiable(list));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Could not read provider data (${e.runtimeType}).'),
      );
    }
  }

  String _facilityTypeFor(ProviderKind kind) => switch (kind) {
        ProviderKind.lab => 'LAB',
        ProviderKind.imaging => 'IMAGING',
        ProviderKind.pharmacy => 'PHARMACY',
        ProviderKind.clinician =>
          throw ArgumentError('Clinicians are not a Facility.'),
      };
}

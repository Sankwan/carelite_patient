
import '../../../core/utils/result.dart';
import '../domain/provider.dart';

abstract class ProviderRepository {
  /// Providers within [radiusMetres] of a point, nearest first.
  Future<Result<List<Provider>>> fetchNearby({
    required double latitude,
    required double longitude,
    ProviderKind? kind,
    int radiusMetres,
    int limit,
  });

  /// Fallback for a patient who declined location: same providers, no
  /// distances, so the screen still has content instead of an empty state
  /// caused by a permission the patient is entitled to refuse.
  Future<Result<List<Provider>>> fetchVerified({ProviderKind? kind, int limit});
}

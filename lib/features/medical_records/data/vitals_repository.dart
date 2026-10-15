import '../../../core/utils/result.dart';
import '../domain/vitals_record.dart';

abstract class VitalsRepository {
  /// The signed-in patient's own vitals across every consultation, oldest
  /// first as the server returns them.
  Future<Result<List<VitalsRecord>>> fetchTrend();
}

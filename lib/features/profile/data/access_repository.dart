import '../../../core/utils/result.dart';
import '../domain/access_request.dart';

abstract class AccessRepository {
  /// Requests targeting the signed-in patient, newest first.
  Future<Result<List<AccessRequest>>> fetchRequests();

  Future<Result<AccessRequest>> approve(String requestId);
  Future<Result<AccessRequest>> decline(String requestId);
  Future<Result<AccessRequest>> revoke(String requestId);
}

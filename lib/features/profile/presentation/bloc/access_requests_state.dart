import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/access_request.dart';

enum AccessRequestsStatus { loading, ready }

final class AccessRequestsState extends Equatable {
  const AccessRequestsState({
    this.status = AccessRequestsStatus.loading,
    this.requests = const [],
    this.decidingId,
    this.failure,
  });

  final AccessRequestsStatus status;
  final List<AccessRequest> requests;

  /// The one request currently being approved/declined/revoked, if any —
  /// so only its own button shows a spinner, not the whole list.
  final String? decidingId;
  final Failure? failure;

  List<AccessRequest> get pending =>
      requests.where((r) => r.isPending).toList(growable: false);
  List<AccessRequest> get decided =>
      requests.where((r) => !r.isPending).toList(growable: false);

  AccessRequestsState copyWith({
    AccessRequestsStatus? status,
    List<AccessRequest>? requests,
    String? decidingId,
    Failure? failure,
    bool clearDecidingId = false,
    bool clearFailure = false,
  }) {
    return AccessRequestsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      decidingId: clearDecidingId ? null : decidingId ?? this.decidingId,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, requests, decidingId, failure];
}

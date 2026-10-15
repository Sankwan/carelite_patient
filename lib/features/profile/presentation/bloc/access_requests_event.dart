import 'package:equatable/equatable.dart';

sealed class AccessRequestsEvent extends Equatable {
  const AccessRequestsEvent();

  @override
  List<Object?> get props => [];
}

final class AccessRequestsStarted extends AccessRequestsEvent {
  const AccessRequestsStarted();
}

final class AccessRequestsRefreshed extends AccessRequestsEvent {
  const AccessRequestsRefreshed();
}

enum AccessDecision { approve, decline, revoke }

final class AccessRequestDecided extends AccessRequestsEvent {
  const AccessRequestDecided(this.requestId, this.decision);

  final String requestId;
  final AccessDecision decision;

  @override
  List<Object?> get props => [requestId, decision];
}

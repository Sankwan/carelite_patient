import 'package:equatable/equatable.dart';

/// The four items PT-PRECALL requires — verified against
/// `appointments.serializers.PreCallAckSerializer`, whose `validate()`
/// rejects the POST unless every one of these is true. "Join Call" is a
/// gate, not a toast: the button stays disabled until all four are checked.
class PrecallChecklist extends Equatable {
  const PrecallChecklist({
    this.quietLocation = false,
    this.cameraMicOk = false,
    this.connectionOk = false,
    this.documentsReady = false,
  });

  final bool quietLocation;
  final bool cameraMicOk;
  final bool connectionOk;
  final bool documentsReady;

  bool get isComplete =>
      quietLocation && cameraMicOk && connectionOk && documentsReady;

  PrecallChecklist copyWith({
    bool? quietLocation,
    bool? cameraMicOk,
    bool? connectionOk,
    bool? documentsReady,
  }) {
    return PrecallChecklist(
      quietLocation: quietLocation ?? this.quietLocation,
      cameraMicOk: cameraMicOk ?? this.cameraMicOk,
      connectionOk: connectionOk ?? this.connectionOk,
      documentsReady: documentsReady ?? this.documentsReady,
    );
  }

  Map<String, dynamic> toJson() => {
        'quiet_location': quietLocation,
        'camera_mic_ok': cameraMicOk,
        'connection_ok': connectionOk,
        'documents_ready': documentsReady,
      };

  @override
  List<Object?> get props =>
      [quietLocation, cameraMicOk, connectionOk, documentsReady];
}

/// The gate state for one appointment — `GET .../precall/`'s shape,
/// verified live. [bothReady] is what actually unblocks a real two-sided
/// call; [canJoin] only reflects the current user's own acknowledgement.
class PrecallStatus extends Equatable {
  const PrecallStatus({
    this.youAcknowledged = false,
    this.canJoin = false,
    this.bothReady = false,
  });

  factory PrecallStatus.fromDjangoJson(Map<String, dynamic> row) {
    return PrecallStatus(
      youAcknowledged: row['you_acknowledged'] as bool? ?? false,
      canJoin: row['can_join'] as bool? ?? false,
      bothReady: row['both_ready'] as bool? ?? false,
    );
  }

  final bool youAcknowledged;
  final bool canJoin;
  final bool bothReady;

  @override
  List<Object?> get props => [youAcknowledged, canJoin, bothReady];
}

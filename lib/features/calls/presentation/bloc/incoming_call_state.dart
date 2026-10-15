import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../../home/domain/appointment.dart';
import '../../domain/call_session.dart';

enum IncomingCallStatus {
  loading,
  ringing,
  declining,

  /// The call stopped ringing: declined here, answered elsewhere, or the
  /// clinician hung up. The screen closes.
  over,
  failed,
}

final class IncomingCallState extends Equatable {
  const IncomingCallState({
    this.status = IncomingCallStatus.loading,
    this.session,
    this.appointment,
    this.needsPrecall = true,
    this.failure,
  });

  final IncomingCallStatus status;
  final CallSession? session;
  final Appointment? appointment;

  /// The server refuses an answer until the checklist is done, so Answer
  /// goes through it first when this is true.
  final bool needsPrecall;
  final Failure? failure;

  IncomingCallState copyWith({
    IncomingCallStatus? status,
    CallSession? session,
    Appointment? appointment,
    bool? needsPrecall,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return IncomingCallState(
      status: status ?? this.status,
      session: session ?? this.session,
      appointment: appointment ?? this.appointment,
      needsPrecall: needsPrecall ?? this.needsPrecall,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, session, appointment, needsPrecall, failure];
}

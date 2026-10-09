import '../../../core/utils/result.dart';
import '../domain/call_session.dart';
import '../domain/precall_checklist.dart';

abstract class CallRepository {
  /// The current gate state for one appointment.
  Future<Result<PrecallStatus>> fetchPrecallStatus(String appointmentId);

  /// Submits the checklist. The server rejects it (400) unless every item
  /// is true — this never claims success for a partial submission.
  Future<Result<PrecallStatus>> submitPrecallChecklist(
    String appointmentId,
    PrecallChecklist checklist,
  );

  /// Starts a call for this appointment. The server requires the caller's
  /// own pre-call ack first and refuses (403) otherwise.
  Future<Result<CallSession>> initiateCall(String appointmentId, CallMode mode);

  /// Polls one call's current state.
  Future<Result<CallSession>> fetchCall(String callId);

  Future<Result<CallSession>> endCall(String callId);
}

import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/precall_checklist.dart';

enum PrecallStepStatus { loading, ready, submitting }

class PrecallState extends Equatable {
  const PrecallState({
    this.status = PrecallStepStatus.loading,
    this.checklist = const PrecallChecklist(),
    this.serverStatus = const PrecallStatus(),
    this.failure,
  });

  final PrecallStepStatus status;

  /// What the patient has ticked on screen, not yet submitted.
  final PrecallChecklist checklist;

  /// The server's last-known view — including whether the *other*
  /// participant is ready, which the local checklist can never know.
  final PrecallStatus serverStatus;

  final Failure? failure;

  /// Enabled once every item is ticked locally — matches the server's own
  /// all-or-nothing validation, so the button is never enabled for a
  /// request that would 400.
  bool get canSubmit =>
      checklist.isComplete && status != PrecallStepStatus.submitting;

  PrecallState copyWith({
    PrecallStepStatus? status,
    PrecallChecklist? checklist,
    PrecallStatus? serverStatus,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PrecallState(
      status: status ?? this.status,
      checklist: checklist ?? this.checklist,
      serverStatus: serverStatus ?? this.serverStatus,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, checklist, serverStatus, failure];
}

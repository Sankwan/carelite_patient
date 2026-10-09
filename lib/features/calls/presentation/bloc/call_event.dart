import 'package:equatable/equatable.dart';

import '../../domain/call_session.dart';

sealed class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

/// Initiates the call. This app only ever initiates — there is no scenario
/// where a patient receives one (see docs/PROJECT_STATUS.md).
final class CallStarted extends CallEvent {
  const CallStarted({this.mode = CallMode.video});

  final CallMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Internal: fired on a timer while the call is still ringing or accepted,
/// so a second participant answering (from a curl call, or a future
/// clinician client) is reflected without the patient doing anything.
final class CallPolled extends CallEvent {
  const CallPolled();
}

final class CallEndRequested extends CallEvent {
  const CallEndRequested();
}

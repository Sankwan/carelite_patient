import 'package:equatable/equatable.dart';

sealed class IncomingCallEvent extends Equatable {
  const IncomingCallEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the call and its appointment, and whether the patient still has
/// to do the pre-call checklist before they can answer.
final class IncomingCallStarted extends IncomingCallEvent {
  const IncomingCallStarted();
}

final class IncomingCallDeclined extends IncomingCallEvent {
  const IncomingCallDeclined();
}

/// Internal: the server says this call changed — most often, the clinician
/// hung up before the patient answered.
final class IncomingCallChanged extends IncomingCallEvent {
  const IncomingCallChanged();
}

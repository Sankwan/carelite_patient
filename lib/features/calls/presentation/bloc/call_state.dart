import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/call_session.dart';

enum CallLifecycle { connecting, live, ending, failed }

class CallState extends Equatable {
  const CallState({
    this.lifecycle = CallLifecycle.connecting,
    this.session,
    this.failure,
  });

  final CallLifecycle lifecycle;
  final CallSession? session;
  final Failure? failure;

  CallState copyWith({
    CallLifecycle? lifecycle,
    CallSession? session,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CallState(
      lifecycle: lifecycle ?? this.lifecycle,
      session: session ?? this.session,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [lifecycle, session, failure];
}

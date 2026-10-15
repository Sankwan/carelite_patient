import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/chat_message.dart';

enum ThreadStatus { loading, ready }

class ThreadState extends Equatable {
  const ThreadState({
    this.status = ThreadStatus.loading,
    this.messages = const [],
    this.failure,
    this.unsentBody,
  });

  final ThreadStatus status;

  /// Oldest first, as a chat reads.
  final List<ChatMessage> messages;
  final Failure? failure;

  /// The text of a message that failed to send, handed back to the input
  /// so the patient does not have to type it again.
  final String? unsentBody;

  ThreadState copyWith({
    ThreadStatus? status,
    List<ChatMessage>? messages,
    Failure? failure,
    String? unsentBody,
    bool clearFailure = false,
    bool clearUnsent = false,
  }) {
    return ThreadState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      failure: clearFailure ? null : (failure ?? this.failure),
      unsentBody: clearUnsent ? null : (unsentBody ?? this.unsentBody),
    );
  }

  @override
  List<Object?> get props => [status, messages, failure, unsentBody];
}

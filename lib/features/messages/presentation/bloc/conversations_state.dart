import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/conversation.dart';

enum ConversationsStatus { loading, ready }

class ConversationsState extends Equatable {
  const ConversationsState({
    this.status = ConversationsStatus.loading,
    this.conversations = const [],
    this.failure,
  });

  final ConversationsStatus status;
  final List<Conversation> conversations;
  final Failure? failure;

  ConversationsState copyWith({
    ConversationsStatus? status,
    List<Conversation>? conversations,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ConversationsState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, conversations, failure];
}

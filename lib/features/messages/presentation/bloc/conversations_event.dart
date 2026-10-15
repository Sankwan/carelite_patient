import 'package:equatable/equatable.dart';

sealed class ConversationsEvent extends Equatable {
  const ConversationsEvent();

  @override
  List<Object?> get props => [];
}

final class ConversationsStarted extends ConversationsEvent {
  const ConversationsStarted();
}

/// Pull-to-refresh, a returned thread, or a live "message" event.
final class ConversationsRefreshed extends ConversationsEvent {
  const ConversationsRefreshed();
}

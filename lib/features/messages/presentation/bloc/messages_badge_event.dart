import 'package:equatable/equatable.dart';

sealed class MessagesBadgeEvent extends Equatable {
  const MessagesBadgeEvent();

  @override
  List<Object?> get props => [];
}

/// Refetch the unread count: on sign-in, when a message arrives, and when
/// the patient closes a thread they have just read.
final class MessagesBadgeRefreshed extends MessagesBadgeEvent {
  const MessagesBadgeRefreshed();
}

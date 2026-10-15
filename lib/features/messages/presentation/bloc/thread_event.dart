import 'package:equatable/equatable.dart';

sealed class ThreadEvent extends Equatable {
  const ThreadEvent();

  @override
  List<Object?> get props => [];
}

final class ThreadOpened extends ThreadEvent {
  const ThreadOpened();
}

/// A live "message" event for this conversation, or pull-to-refresh.
final class ThreadRefreshed extends ThreadEvent {
  const ThreadRefreshed();
}

final class ThreadMessageSent extends ThreadEvent {
  const ThreadMessageSent(this.body);

  final String body;

  @override
  List<Object?> get props => [body];
}

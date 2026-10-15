import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/messaging_repository.dart';
import 'messages_badge_event.dart';

/// The unread-message count on the Messages tab. The state is the count.
///
/// One instance for the app's lifetime, because the tab bar outlives every
/// screen. A failed count keeps the last known value: a badge is not worth
/// an error message.
class MessagesBadgeBloc extends Bloc<MessagesBadgeEvent, int> {
  MessagesBadgeBloc({
    required MessagingRepository messagingRepository,
    Stream<void>? messagesChanged,
  })  : _repository = messagingRepository,
        super(0) {
    on<MessagesBadgeRefreshed>(_onRefreshed, transformer: _latestOnly);
    _changes =
        messagesChanged?.listen((_) => add(const MessagesBadgeRefreshed()));
  }

  final MessagingRepository _repository;
  StreamSubscription<void>? _changes;

  Future<void> _onRefreshed(
    MessagesBadgeRefreshed event,
    Emitter<int> emit,
  ) async {
    final result = await _repository.fetchUnreadCount();
    result.when(ok: emit.call, err: (_) {});
  }

  /// A burst of arrivals needs one count, not one request each.
  static Stream<E> _latestOnly<E>(
    Stream<E> events,
    Stream<E> Function(E) mapper,
  ) =>
      events.asyncExpand(mapper);

  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}

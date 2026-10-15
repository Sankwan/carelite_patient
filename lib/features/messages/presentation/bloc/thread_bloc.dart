import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/messaging_repository.dart';
import '../../domain/chat_message.dart';
import 'thread_event.dart';
import 'thread_state.dart';

class ThreadBloc extends Bloc<ThreadEvent, ThreadState> {
  ThreadBloc({
    required MessagingRepository messagingRepository,
    required this.conversationId,
    Stream<String>? messageArrived,
  })  : _repository = messagingRepository,
        super(const ThreadState()) {
    on<ThreadOpened>((_, emit) => _load(emit));
    on<ThreadRefreshed>((_, emit) => _load(emit));
    on<ThreadMessageSent>(_onSent);
    _arrivals = messageArrived
        ?.where((id) => id == conversationId)
        .listen((_) => add(const ThreadRefreshed()));
  }

  final MessagingRepository _repository;
  final String conversationId;
  StreamSubscription<String>? _arrivals;

  Future<void> _load(Emitter<ThreadState> emit) async {
    try {
      final result = await _repository.fetchRecentMessages(conversationId);
      result.when(
        ok: (messages) => emit(state.copyWith(
          status: ThreadStatus.ready,
          messages: [...messages, ...state.messages.where((m) => m.isPending)],
          clearFailure: true,
        )),
        err: (failure) =>
            emit(state.copyWith(status: ThreadStatus.ready, failure: failure)),
      );
      // Opening or refreshing the thread means the patient has seen it.
      await _repository.markRead(conversationId);
    } catch (e) {
      emit(state.copyWith(
        status: ThreadStatus.ready,
        failure: UnexpectedFailure('Could not load messages (${e.runtimeType}).'),
      ));
    }
  }

  Future<void> _onSent(ThreadMessageSent event, Emitter<ThreadState> emit) async {
    final body = event.body.trim();
    if (body.isEmpty) return;
    // Shown at once so the conversation feels immediate; replaced by the
    // server's copy, or removed and handed back if the send fails.
    final pending = ChatMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      body: body,
      mine: true,
      sentAt: DateTime.now(),
      isPending: true,
    );
    emit(state.copyWith(
      messages: [...state.messages, pending],
      clearFailure: true,
      clearUnsent: true,
    ));
    final result = await _repository.send(conversationId, body);
    final others = state.messages.where((m) => m.id != pending.id).toList();
    result.when(
      ok: (sent) => emit(state.copyWith(messages: [...others, sent])),
      err: (failure) => emit(state.copyWith(
        messages: others,
        failure: failure,
        unsentBody: body,
      )),
    );
  }

  @override
  Future<void> close() {
    _arrivals?.cancel();
    return super.close();
  }
}

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/messaging_repository.dart';
import 'conversations_event.dart';
import 'conversations_state.dart';

class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({
    required MessagingRepository messagingRepository,
    Stream<void>? messagesChanged,
  })  : _repository = messagingRepository,
        super(const ConversationsState()) {
    on<ConversationsStarted>((_, emit) => _load(emit));
    on<ConversationsRefreshed>((_, emit) => _load(emit));
    _changes = messagesChanged?.listen((_) => add(const ConversationsRefreshed()));
  }

  final MessagingRepository _repository;
  StreamSubscription<void>? _changes;

  Future<void> _load(Emitter<ConversationsState> emit) async {
    try {
      final result = await _repository.fetchConversations();
      result.when(
        ok: (conversations) => emit(state.copyWith(
          status: ConversationsStatus.ready,
          conversations: conversations,
          clearFailure: true,
        )),
        // Keep what is already on screen; the failure is shown over it.
        err: (failure) => emit(state.copyWith(
          status: ConversationsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      emit(state.copyWith(
        status: ConversationsStatus.ready,
        failure: UnexpectedFailure('Could not load messages (${e.runtimeType}).'),
      ));
    }
  }

  @override
  Future<void> close() {
    _changes?.cancel();
    return super.close();
  }
}

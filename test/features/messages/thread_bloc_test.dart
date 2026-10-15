import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/messages/data/messaging_repository.dart';
import 'package:carelite_app/features/messages/domain/chat_message.dart';
import 'package:carelite_app/features/messages/presentation/bloc/thread_bloc.dart';
import 'package:carelite_app/features/messages/presentation/bloc/thread_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagingRepository extends Mock implements MessagingRepository {}

void main() {
  late _MockMessagingRepository repository;
  final sent = ChatMessage(
    id: '9',
    body: 'Thank you',
    mine: true,
    sentAt: DateTime(2026, 10, 15, 10),
  );

  setUp(() {
    repository = _MockMessagingRepository();
    when(() => repository.markRead(any()))
        .thenAnswer((_) async => const Result.ok(null));
  });

  blocTest<ThreadBloc, dynamic>(
    'opening a thread loads it and marks it read',
    build: () {
      when(() => repository.fetchRecentMessages('7'))
          .thenAnswer((_) async => Result.ok([sent]));
      return ThreadBloc(messagingRepository: repository, conversationId: '7');
    },
    act: (bloc) => bloc.add(const ThreadOpened()),
    verify: (bloc) {
      expect(bloc.state.messages, [sent]);
      verify(() => repository.markRead('7')).called(1);
    },
  );

  blocTest<ThreadBloc, dynamic>(
    'a message shows at once, then is replaced by the server\'s copy',
    build: () {
      when(() => repository.send('7', 'Thank you'))
          .thenAnswer((_) async => Result.ok(sent));
      return ThreadBloc(messagingRepository: repository, conversationId: '7');
    },
    act: (bloc) => bloc.add(const ThreadMessageSent('  Thank you ')),
    verify: (bloc) {
      expect(bloc.state.messages, [sent]);
    },
  );

  blocTest<ThreadBloc, dynamic>(
    'a failed send is removed and its text handed back',
    build: () {
      when(() => repository.send('7', 'Thank you'))
          .thenAnswer((_) async => const Result.err(NetworkFailure()));
      return ThreadBloc(messagingRepository: repository, conversationId: '7');
    },
    act: (bloc) => bloc.add(const ThreadMessageSent('Thank you')),
    verify: (bloc) {
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.unsentBody, 'Thank you');
      expect(bloc.state.failure, isA<NetworkFailure>());
    },
  );

  blocTest<ThreadBloc, dynamic>(
    'a live message event for this thread reloads it; others are ignored',
    build: () {
      when(() => repository.fetchRecentMessages('7'))
          .thenAnswer((_) async => Result.ok([sent]));
      return ThreadBloc(
        messagingRepository: repository,
        conversationId: '7',
        messageArrived: Stream.fromIterable(['3', '7']),
      );
    },
    wait: const Duration(milliseconds: 50),
    verify: (_) {
      verify(() => repository.fetchRecentMessages('7')).called(1);
    },
  );
}

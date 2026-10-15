import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/messages/data/django_messaging_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

Map<String, dynamic> _message(int id, {bool mine = false}) => {
      'id': id,
      'conversation': 7,
      'sender': mine ? 'me-uuid' : 'dr-uuid',
      'sender_name': mine ? 'Kofi Asante' : 'Kwame Adjei',
      'mine': mine,
      'body': 'message $id',
      'created_at': '2026-10-15T10:00:00Z',
    };

Map<String, dynamic> _page(int count, Iterable<int> ids) => {
      'count': count,
      'next': null,
      'previous': null,
      'results': [for (final id in ids) _message(id)],
    };

void main() {
  late _MockApiClient client;
  late DjangoMessagingRepository repository;
  final path = ApiContract.conversationMessages('7');

  setUp(() {
    client = _MockApiClient();
    repository = DjangoMessagingRepository(
      client,
      currentUserId: () async => 'me-uuid',
    );
  });

  test('reads a conversation from the patient\'s side', () async {
    when(() => client.get(ApiContract.conversations)).thenAnswer(
      (_) async => _response(200, {
        'count': 1,
        'results': [
          {
            'id': 7,
            'other_participant': {
              'id': 'dr-uuid',
              'username': 'dr_adjei',
              'full_name': 'Kwame Adjei',
              'role': 'CLINICIAN',
            },
            'last_message': {
              'body': 'See you Monday',
              'created_at': '2026-10-15T10:00:00Z',
              'sender': 'me-uuid',
            },
            'unread_count': 2,
            'last_message_at': '2026-10-15T10:00:00Z',
            'created_at': '2026-10-14T10:00:00Z',
          },
        ],
      }),
    );

    final result = await repository.fetchConversations();

    final conversation = result.when(ok: (v) => v.single, err: (f) => throw f);
    expect(conversation.clinicianName, 'Dr. Kwame Adjei');
    expect(conversation.lastMessage, 'See you Monday');
    expect(conversation.lastMessageIsMine, isTrue);
    expect(conversation.unreadCount, 2);
  });

  group('recent messages', () {
    // The server pages oldest-first, 20 per page. Reading only page 1 would
    // show the start of a long thread and never the latest replies.
    test('a short thread is one page', () async {
      when(() => client.get(path))
          .thenAnswer((_) async => _response(200, _page(5, [1, 2, 3, 4, 5])));

      final result = await repository.fetchRecentMessages('7');

      expect(result.when(ok: (v) => v.length, err: (_) => -1), 5);
      verify(() => client.get(path, query: any(named: 'query'))).called(1);
    });

    test('a two-page thread returns both pages in order', () async {
      when(() => client.get(path)).thenAnswer(
        (_) async => _response(200, _page(25, List.generate(20, (i) => i + 1))),
      );
      when(() => client.get(path, query: {'page': 2})).thenAnswer(
        (_) async => _response(200, _page(25, List.generate(5, (i) => i + 21))),
      );

      final result = await repository.fetchRecentMessages('7');

      final ids = result.when(ok: (v) => v.map((m) => m.id), err: (f) => throw f);
      expect(ids.first, '1');
      expect(ids.last, '25');
      expect(ids.length, 25);
    });

    test('a long thread returns the last two pages, ending with the newest',
        () async {
      when(() => client.get(path)).thenAnswer(
        (_) async => _response(200, _page(45, List.generate(20, (i) => i + 1))),
      );
      when(() => client.get(path, query: {'page': 2})).thenAnswer(
        (_) async => _response(200, _page(45, List.generate(20, (i) => i + 21))),
      );
      when(() => client.get(path, query: {'page': 3})).thenAnswer(
        (_) async => _response(200, _page(45, List.generate(5, (i) => i + 41))),
      );

      final result = await repository.fetchRecentMessages('7');

      final ids = result.when(ok: (v) => v.map((m) => m.id), err: (f) => throw f);
      expect(ids.first, '21');
      expect(ids.last, '45');
    });
  });

  test('a sent message comes back as the server stored it', () async {
    when(() => client.post(path, data: {'body': 'Thank you'})).thenAnswer(
      (_) async => _response(201, _message(9, mine: true)..['body'] = 'Thank you'),
    );

    final result = await repository.send('7', 'Thank you');

    final message = result.when(ok: (v) => v, err: (f) => throw f);
    expect(message.mine, isTrue);
    expect(message.body, 'Thank you');
  });

  test('a refused send surfaces the server\'s reason', () async {
    when(() => client.post(path, data: any(named: 'data'))).thenAnswer(
      (_) async => _response(403, {'detail': 'You do not have permission.'}),
    );

    final result = await repository.send('7', 'hi');

    expect(result.when(ok: (_) => null, err: (f) => f.message),
        'You do not have permission.');
  });
}

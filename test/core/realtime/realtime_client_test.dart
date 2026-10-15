import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:carelite_app/core/network/api/token_store.dart';
import 'package:carelite_app/core/realtime/realtime_client.dart';
import 'package:carelite_app/core/realtime/realtime_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeTokenStore extends Fake implements TokenStore {
  String? access = 'token-1';

  @override
  Future<String?> readAccess() async => access;
}

/// A socket the test drives: [serverSends] pushes a frame to the app,
/// [serverCloses] ends it with a close code.
class _FakeChannel extends Fake implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  int? _closeCode;

  void serverSends(Map<String, dynamic> frame) =>
      _incoming.add(jsonEncode(frame));

  Future<void> serverCloses([int? code]) {
    _closeCode = code;
    return _incoming.close();
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  WebSocketSink get sink => _FakeSink(this);
}

class _FakeSink extends Fake implements WebSocketSink {
  _FakeSink(this._channel);
  final _FakeChannel _channel;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_channel._incoming.isClosed) await _channel._incoming.close();
  }
}

void main() {
  late _FakeTokenStore tokens;
  late List<_FakeChannel> opened;
  late List<Uri> uris;
  late int refreshes;
  late WebSocketRealtimeClient client;

  setUp(() {
    tokens = _FakeTokenStore();
    opened = [];
    uris = [];
    refreshes = 0;
    client = WebSocketRealtimeClient(
      tokenStore: tokens,
      refreshSession: () async {
        refreshes++;
        tokens.access = 'token-2';
      },
      connector: (uri) {
        uris.add(uri);
        final channel = _FakeChannel();
        opened.add(channel);
        return channel;
      },
      backoff: (_) => Duration.zero,
    );
  });

  tearDown(() => client.disconnect(endSession: true));

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

  test('the socket address follows the API host and scheme', () {
    expect(
      WebSocketRealtimeClient.socketUri('http://10.0.2.2:8000', 'abc').toString(),
      'ws://10.0.2.2:8000/ws/realtime/?token=abc',
    );
    expect(
      WebSocketRealtimeClient.socketUri('https://api.carelite.health', 'abc')
          .scheme,
      'wss',
    );
  });

  test('server frames become typed events; unknown ones are dropped', () async {
    final events = StreamQueue(client.events);
    client.connect();
    await settle();
    opened.single
      ..serverSends({'event': 'connected', 'data': <String, dynamic>{}})
      ..serverSends({'event': 'something_new', 'data': <String, dynamic>{}})
      ..serverSends({
        'event': 'call',
        'data': {'call_id': 4, 'status': 'ACCEPTED'},
      })
      ..serverSends({
        'event': 'message',
        'data': {'conversation_id': 7},
      })
      ..serverSends({
        'event': 'notification',
        'data': {
          'id': 12,
          'type': 'CLINICIAN_ASSIGNED',
          'title': 'Clinician assigned',
          'body': 'Dr. Adjei will see you.',
          'payload': {'appointment_id': 3},
        },
      });

    // The first "connected" of a session is not a catch-up.
    expect(await events.next,
        const RealtimeCallChanged(callId: '4', status: 'ACCEPTED'));
    expect(await events.next, const RealtimeMessageArrived('7'));
    final notification = await events.next as RealtimeNotification;
    expect(notification.type, 'CLINICIAN_ASSIGNED');
    expect(notification.payload['appointment_id'], 3);
    await events.cancel();
  });

  test('a dropped socket reconnects and announces the catch-up', () async {
    final events = StreamQueue(client.events);
    client.connect();
    await settle();
    opened.first.serverSends({'event': 'connected', 'data': <String, dynamic>{}});
    await opened.first.serverCloses(1006);
    await settle();

    expect(opened, hasLength(2));
    opened.last.serverSends({'event': 'connected', 'data': <String, dynamic>{}});
    expect(await events.next, const RealtimeReconnected());
    expect(refreshes, 0, reason: 'only an auth close needs a new token');
    await events.cancel();
  });

  test('an expired token is refreshed before reconnecting', () async {
    client.connect();
    await settle();
    await opened.first.serverCloses(4001);
    await settle();

    expect(refreshes, 1);
    expect(uris.last.queryParameters['token'], 'token-2');
  });

  test('after sign-out nothing reconnects', () async {
    client.connect();
    await settle();
    await client.disconnect(endSession: true);
    await settle();

    expect(opened, hasLength(1));
  });

  test('a stream helper maps a reconnect to the open thread', () async {
    final source = Stream<RealtimeEvent>.fromIterable(const [
      RealtimeMessageArrived('3'),
      RealtimeReconnected(),
      RealtimeCallChanged(callId: '1', status: 'ENDED'),
    ]);

    expect(await source.conversationChanges('9').toList(), ['3', '9']);
  });
}

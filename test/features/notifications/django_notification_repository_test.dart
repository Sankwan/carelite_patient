import 'package:carelite_app/core/network/api/api_client.dart';
import 'package:carelite_app/core/network/api/api_contract.dart';
import 'package:carelite_app/features/notifications/data/django_notification_repository.dart';
import 'package:carelite_app/features/notifications/domain/app_notification.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

Response<dynamic> _response(int status, dynamic body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data: body,
    );

/// Shaped after `notifications.serializers.NotificationSerializer` as it came
/// back from a live instance. `channel` defaults to `IN_APP` — the only
/// channel meant to render as a notification card; see the repository's own
/// comment on why the other two (`SMS`, `PUSH`) exist in this feed at all.
Map<String, dynamic> _row({
  required int id,
  String type = 'CLINICIAN_ASSIGNED',
  String channel = 'IN_APP',
  String? readAt,
  Map<String, dynamic> payload = const {'appointment_id': 9},
}) {
  return {
    'id': id,
    'type': type,
    'channel': channel,
    'title': 'Dr. Adjei accepted your request',
    'body': 'Your consultation is confirmed.',
    'payload': payload,
    'read_at': readAt,
    'created_at': '2026-09-08T09:15:00Z',
  };
}

void main() {
  late _MockApiClient client;
  late DjangoNotificationRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = DjangoNotificationRepository(client);
    registerFallbackValue(<String, dynamic>{});
  });

  test('unwraps the DRF pagination envelope and maps the wire types',
      () async {
    when(() => client.get(ApiContract.notifications, query: any(named: 'query'))).thenAnswer(
      (_) async => _response(200, {
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          _row(id: 1),
          _row(id: 2, type: 'RESULT_READY', readAt: '2026-09-08T10:00:00Z'),
        ],
      }),
    );

    final result = await repository.fetchAll();

    final list =
        result.when(ok: (v) => v, err: (f) => throw f);
    expect(list.map((n) => n.id), ['1', '2']);
    expect(list.first.type, NotificationType.clinicianAssigned);
    expect(list.first.isUnread, isTrue);
    expect(list.last.type, NotificationType.resultReady);
    expect(list.last.isUnread, isFalse);
    expect(list.first.appointmentId, 9);
  });

  test(
      'a single logical event fanned out across IN_APP/SMS/PUSH channels '
      'renders once, not three times', () async {
    // Verified live: `notify(..., channels=("IN_APP", "SMS", "PUSH"))`
    // (INCOMING_CALL's own channel set) creates three Notification rows
    // with identical title/body/payload, one per channel — confirmed
    // directly against the demo database. The endpoint's own docstring
    // calls this intentional ("in-app + a record of SMS/push"), so only the
    // IN_APP row is meant to be shown as a card.
    when(() => client.get(ApiContract.notifications, query: any(named: 'query'))).thenAnswer(
      (_) async => _response(200, {
        'results': [
          _row(id: 10, type: 'INCOMING_CALL'),
          _row(id: 11, type: 'INCOMING_CALL', channel: 'SMS'),
          _row(id: 12, type: 'INCOMING_CALL', channel: 'PUSH'),
        ],
      }),
    );

    final result = await repository.fetchAll();

    final list = result.when(ok: (v) => v, err: (f) => throw f);
    expect(list, hasLength(1));
    expect(list.single.id, '10');
  });

  test('an unrecognised type degrades to generic instead of throwing',
      () async {
    // The backend can add a Notification.Type the app has never heard of;
    // that must show up as a plain notification, not crash the screen.
    when(() => client.get(ApiContract.notifications, query: any(named: 'query'))).thenAnswer(
      (_) async => _response(200, {
        'results': [_row(id: 3, type: 'SOME_FUTURE_TYPE')],
      }),
    );

    final result = await repository.fetchAll();

    final list = result.when(ok: (v) => v, err: (f) => throw f);
    expect(list.single.type, NotificationType.generic);
  });

  test('a malformed row is a visible failure, never an uncaught throw',
      () async {
    when(() => client.get(ApiContract.notifications, query: any(named: 'query'))).thenAnswer(
      (_) async => _response(200, {
        'results': [
          _row(id: 4)..['created_at'] = null,
        ],
      }),
    );

    final result = await repository.fetchAll();

    expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
  });

  test('fetchUnreadCount reads the server\'s count', () async {
    when(() => client.get(ApiContract.notificationsUnreadCount))
        .thenAnswer((_) async => _response(200, {'unread': 3}));

    final result = await repository.fetchUnreadCount();

    expect(result.when(ok: (v) => v, err: (_) => -1), 3);
  });

  test('a non-200 while counting unread is a failure, not a silent zero',
      () async {
    // Zero would be indistinguishable from "all caught up" — the Bloc, not
    // the repository, decides that an uncountable badge should read as none.
    when(() => client.get(ApiContract.notificationsUnreadCount))
        .thenAnswer((_) async => _response(500, null));

    final result = await repository.fetchUnreadCount();

    expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
  });

  test('markRead posts to the per-notification endpoint', () async {
    when(() => client.post(ApiContract.notificationRead('7')))
        .thenAnswer((_) async => _response(200, {'status': 'read'}));

    final result = await repository.markRead('7');

    expect(result.when(ok: (_) => true, err: (_) => false), isTrue);
    verify(() => client.post(ApiContract.notificationRead('7')))
        .called(1);
  });

  test('markAllRead surfaces a rejection instead of reporting success',
      () async {
    when(() => client.post(ApiContract.notificationsReadAll))
        .thenAnswer((_) async => _response(403, null));

    final result = await repository.markAllRead();

    expect(result.when(ok: (_) => null, err: (f) => f), isNotNull);
  });
}

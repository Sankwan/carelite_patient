import 'package:dio/dio.dart';

import '../../../core/network/api/api_client.dart';
import '../../../core/network/api/api_contract.dart';
import '../../../core/network/failure.dart';
import '../../../core/utils/result.dart';
import '../domain/app_notification.dart';
import 'notification_repository.dart';

/// Notifications against the Django API — verified live against
/// `notifications.views.NotificationViewSet` on a running instance
/// (list, ?unread=true, unread-count all hit for real).
class DjangoNotificationRepository implements NotificationRepository {
  const DjangoNotificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<AppNotification>>> fetchAll({bool unreadOnly = false}) async {
    try {
      final response = await _client.get(
        ApiContract.notifications,
        query: unreadOnly ? {'unread': 'true'} : null,
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      try {
        return Result.ok(
          results
              .cast<Map<String, dynamic>>()
              // This endpoint returns one row *per delivery channel*, not
              // one per logical event — verified live: an INCOMING_CALL
              // notify() call with channels=(IN_APP, SMS, PUSH) produces
              // three rows with identical title/body/payload. The
              // endpoint's own docstring calls this intentional ("in-app +
              // a record of SMS/push"), so this is the feed's real shape,
              // not a bug to route around server-side. Only the IN_APP row
              // is meant to be shown as a notification card — the SMS/PUSH
              // rows are delivery records. Filtering here is what stops a
              // single incoming call from rendering as three identical
              // cards.
              .where((row) => row['channel'] == 'IN_APP')
              .map(AppNotification.fromDjangoJson)
              .toList(growable: false),
        );
      } catch (e) {
        // Parsing is a pure-Dart step and throws TypeError/FormatException,
        // never DioException — the gap that once left Home spinning forever.
        // See DjangoAppointmentRepository._fetchAll for that incident.
        return Result.err(UnexpectedFailure(
          'Could not read your notifications (${e.runtimeType}).',
        ));
      }
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<int>> fetchUnreadCount() async {
    try {
      // Deliberately not GET .../unread-count/: that endpoint counts every
      // row regardless of channel, so a single unread incoming call (3
      // rows: IN_APP/SMS/PUSH) inflates the bell to "3". Counting the
      // filtered list instead costs a slightly heavier request for an
      // honest badge — see docs/PROJECT_STATUS.md for the backend ask
      // that would let this go back to the cheap endpoint.
      final response = await _client.get(
        ApiContract.notifications,
        query: const {'unread': 'true'},
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final results = (response.data as Map)['results'];
      if (results is! List) return const Result.err(NetworkFailure());
      // One page only (PAGE_SIZE=20), same as everywhere else in this app —
      // a patient with more than 20 unread notifications would undercount
      // here. Acceptable for a badge that already treats "uncountable" as
      // zero rather than an error; not acceptable for the notifications
      // list itself, which is why fetchAll always reads every page it's
      // given rather than assuming one is enough.
      final count =
          results.cast<Map<String, dynamic>>().where((row) => row['channel'] == 'IN_APP').length;
      return Result.ok(count);
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<void>> markRead(String id) async {
    try {
      final response = await _client.post(ApiContract.notificationRead(id));
      if (response.statusCode == 200) return const Result.ok(null);
      return const Result.err(
        UnexpectedFailure('Could not mark that as read.'),
      );
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }

  @override
  Future<Result<void>> markAllRead() async {
    try {
      final response = await _client.post(ApiContract.notificationsReadAll);
      if (response.statusCode == 200) return const Result.ok(null);
      return const Result.err(
        UnexpectedFailure('Could not mark everything as read.'),
      );
    } on DioException catch (_) {
      return const Result.err(NetworkFailure());
    }
  }
}

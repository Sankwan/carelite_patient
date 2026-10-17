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
      final response = await _client.getAllPages(
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
      // Counts IN_APP rows only since the backend's B3 fix, so one incoming
      // call is a badge of 1, and it is not limited to the first page the
      // way counting the list was.
      final response = await _client.get(ApiContract.notificationsUnreadCount);
      if (response.statusCode != 200 || response.data is! Map) {
        return const Result.err(NetworkFailure());
      }
      final unread = (response.data as Map)['unread'];
      if (unread is! int) return const Result.err(NetworkFailure());
      return Result.ok(unread);
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

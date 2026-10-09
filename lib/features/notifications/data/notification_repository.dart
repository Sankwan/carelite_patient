import '../../../core/utils/result.dart';
import '../domain/app_notification.dart';

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> fetchAll({bool unreadOnly});

  /// Drives the Home header's bell badge.
  Future<Result<int>> fetchUnreadCount();

  Future<Result<void>> markRead(String id);

  Future<Result<void>> markAllRead();
}

import 'package:equatable/equatable.dart';

import '../../../../core/network/failure.dart';
import '../../domain/app_notification.dart';
import 'notifications_event.dart';

enum NotificationsStatus { loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.notifications = const [],
    this.filter = NotificationsFilter.today,
    this.failure,
  });

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final NotificationsFilter filter;
  final Failure? failure;

  /// What the visible tab actually shows. "Past" is everything before
  /// today, so the two tabs together always account for every notification —
  /// nothing can fall between them and become invisible.
  List<AppNotification> visible({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    bool isBeforeToday(AppNotification n) => DateTime(
          n.createdAt.year,
          n.createdAt.month,
          n.createdAt.day,
        ).isBefore(today);

    return notifications
        .where((n) =>
            filter == NotificationsFilter.past ? isBeforeToday(n) : !isBeforeToday(n))
        .toList(growable: false);
  }

  /// The count beside the "Today" tab label in the design.
  int todayCount({DateTime? now}) =>
      const NotificationsState().copyWith(
        notifications: notifications,
        filter: NotificationsFilter.today,
      ).visible(now: now).length;

  int get unreadCount => notifications.where((n) => n.isUnread).length;

  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    NotificationsFilter? filter,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      filter: filter ?? this.filter,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, notifications, filter, failure];
}

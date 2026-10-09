import 'package:equatable/equatable.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

final class NotificationsStarted extends NotificationsEvent {
  const NotificationsStarted();
}

final class NotificationsRefreshed extends NotificationsEvent {
  const NotificationsRefreshed();
}

/// Today / Past — the two tabs in the design. Filtering happens on the
/// already-fetched page rather than re-querying: the backend's only filter is
/// `?unread=`, there is no date filter, so a second round trip would return
/// exactly the same rows.
final class NotificationsFilterChanged extends NotificationsEvent {
  const NotificationsFilterChanged(this.filter);

  final NotificationsFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class NotificationRead extends NotificationsEvent {
  const NotificationRead(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class NotificationsAllRead extends NotificationsEvent {
  const NotificationsAllRead();
}

enum NotificationsFilter { today, past }

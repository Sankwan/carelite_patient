import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/failure.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification.dart';
import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required NotificationRepository notificationRepository})
      : _notificationRepository = notificationRepository,
        super(const NotificationsState()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsRefreshed>(_onRefreshed);
    on<NotificationsFilterChanged>(_onFilterChanged);
    on<NotificationRead>(_onRead);
    on<NotificationsAllRead>(_onAllRead);
  }

  final NotificationRepository _notificationRepository;

  Future<void> _onStarted(
    NotificationsStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearFailure: true));
    await _load(emit);
  }

  Future<void> _onRefreshed(
    NotificationsRefreshed event,
    Emitter<NotificationsState> emit,
  ) async {
    // No spinner on pull-to-refresh — the list already has content.
    emit(state.copyWith(clearFailure: true));
    await _load(emit);
  }

  void _onFilterChanged(
    NotificationsFilterChanged event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _load(Emitter<NotificationsState> emit) async {
    try {
      final result = await _notificationRepository.fetchAll();
      result.when(
        ok: (notifications) => emit(state.copyWith(
          status: NotificationsStatus.ready,
          notifications: notifications,
          clearFailure: true,
        )),
        err: (failure) => emit(state.copyWith(
          // ready, not failure: an error banner over the list the user
          // already had is better than replacing it with an error page.
          status: NotificationsStatus.ready,
          failure: failure,
        )),
      );
    } catch (e) {
      // Same guard as HomeBloc: an uncaught throw here would strand the
      // screen on its spinner with nothing explaining why.
      emit(state.copyWith(
        status: NotificationsStatus.ready,
        failure: UnexpectedFailure(
          'Could not load notifications (${e.runtimeType}).',
        ),
      ));
    }
  }

  /// Optimistic: the row greys out immediately, and only rolls back if the
  /// server rejects it. Marking read is idempotent server-side (`read_at` is
  /// only set if currently null), so a retry can never do harm.
  Future<void> _onRead(
    NotificationRead event,
    Emitter<NotificationsState> emit,
  ) async {
    final previous = state.notifications;
    final target = previous.where((n) => n.id == event.id).firstOrNull;
    if (target == null || !target.isUnread) return;

    emit(state.copyWith(
      notifications: _replace(previous, event.id, DateTime.now()),
      clearFailure: true,
    ));

    final result = await _notificationRepository.markRead(event.id);
    result.when(
      ok: (_) {},
      err: (failure) => emit(state.copyWith(
        notifications: previous,
        failure: failure,
      )),
    );
  }

  Future<void> _onAllRead(
    NotificationsAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    final previous = state.notifications;
    if (!state.hasUnread) return;

    final now = DateTime.now();
    emit(state.copyWith(
      notifications: previous
          .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
          .toList(growable: false),
      clearFailure: true,
    ));

    final result = await _notificationRepository.markAllRead();
    result.when(
      ok: (_) {},
      err: (failure) => emit(state.copyWith(
        notifications: previous,
        failure: failure,
      )),
    );
  }

  List<AppNotification> _replace(
    List<AppNotification> source,
    String id,
    DateTime readAt,
  ) {
    return source
        .map((n) => n.id == id ? n.copyWith(readAt: readAt) : n)
        .toList(growable: false);
  }
}
